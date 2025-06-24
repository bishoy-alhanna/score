from flask import Blueprint, request, jsonify
import jwt
from src.models.database import db, Score, ScoreAggregate
from sqlalchemy import func
import os

scores_bp = Blueprint('scores', __name__)

def verify_token_and_get_user():
    """Helper function to verify JWT token and return user info"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None, {'error': 'Authorization header required'}, 401
    
    token = auth_header.split(' ')[1]
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    
    try:
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
    except jwt.InvalidTokenError:
        return None, {'error': 'Invalid token'}, 401
    
    return payload, None, None

def update_score_aggregate(user_id=None, group_id=None, category='general', organization_id=None):
    """Update score aggregates for user or group"""
    if user_id:
        # Calculate aggregates for user
        result = db.session.query(
            func.sum(Score.score_value).label('total'),
            func.count(Score.id).label('count'),
            func.avg(Score.score_value).label('average')
        ).filter_by(
            user_id=user_id,
            category=category,
            organization_id=organization_id
        ).first()
        
        # Update or create aggregate
        aggregate = ScoreAggregate.query.filter_by(
            user_id=user_id,
            category=category,
            organization_id=organization_id
        ).first()
        
        if not aggregate:
            aggregate = ScoreAggregate(
                user_id=user_id,
                category=category,
                organization_id=organization_id
            )
            db.session.add(aggregate)
        
        aggregate.total_score = result.total or 0
        aggregate.score_count = result.count or 0
        aggregate.average_score = float(result.average or 0)
        
    elif group_id:
        # Calculate aggregates for group
        result = db.session.query(
            func.sum(Score.score_value).label('total'),
            func.count(Score.id).label('count'),
            func.avg(Score.score_value).label('average')
        ).filter_by(
            group_id=group_id,
            category=category,
            organization_id=organization_id
        ).first()
        
        # Update or create aggregate
        aggregate = ScoreAggregate.query.filter_by(
            group_id=group_id,
            category=category,
            organization_id=organization_id
        ).first()
        
        if not aggregate:
            aggregate = ScoreAggregate(
                group_id=group_id,
                category=category,
                organization_id=organization_id
            )
            db.session.add(aggregate)
        
        aggregate.total_score = result.total or 0
        aggregate.score_count = result.count or 0
        aggregate.average_score = float(result.average or 0)

@scores_bp.route('/', methods=['POST'])
def assign_score():
    """Assign score to user or group"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Check if user is ORG_ADMIN
        if user_payload.get('role') != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can assign scores'}), 403
        
        data = request.get_json()
        
        # Validate required fields
        if not data.get('score_value'):
            return jsonify({'error': 'Score value is required'}), 400
        
        if not data.get('user_id') and not data.get('group_id'):
            return jsonify({'error': 'Either user_id or group_id is required'}), 400
        
        if data.get('user_id') and data.get('group_id'):
            return jsonify({'error': 'Cannot assign score to both user and group'}), 400
        
        score_value = data['score_value']
        user_id = data.get('user_id')
        group_id = data.get('group_id')
        category = data.get('category', 'general')
        description = data.get('description', '')
        organization_id = user_payload['organization_id']
        assigned_by = user_payload['user_id']
        
        # Validate score value
        try:
            score_value = int(score_value)
        except ValueError:
            return jsonify({'error': 'Score value must be an integer'}), 400
        
        # Create new score
        score = Score(
            user_id=user_id,
            group_id=group_id,
            score_value=score_value,
            category=category,
            description=description,
            organization_id=organization_id,
            assigned_by=assigned_by
        )
        
        db.session.add(score)
        db.session.flush()  # Get the score ID
        
        # Update aggregates
        update_score_aggregate(
            user_id=user_id,
            group_id=group_id,
            category=category,
            organization_id=organization_id
        )
        
        db.session.commit()
        
        return jsonify({
            'message': 'Score assigned successfully',
            'score': score.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/', methods=['GET'])
def get_scores():
    """Get scores with optional filters"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Build query with filters
        query = Score.query.filter_by(organization_id=organization_id)
        
        # Filter by user_id
        user_id = request.args.get('user_id')
        if user_id:
            query = query.filter_by(user_id=user_id)
        
        # Filter by group_id
        group_id = request.args.get('group_id')
        if group_id:
            query = query.filter_by(group_id=group_id)
        
        # Filter by category
        category = request.args.get('category')
        if category:
            query = query.filter_by(category=category)
        
        # Pagination
        page = int(request.args.get('page', 1))
        per_page = int(request.args.get('per_page', 50))
        
        scores = query.order_by(Score.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        return jsonify({
            'scores': [s.to_dict() for s in scores.items],
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': scores.total,
                'pages': scores.pages
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/<score_id>', methods=['PUT'])
def update_score(score_id):
    """Update existing score"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Check if user is ORG_ADMIN
        if user_payload.get('role') != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can update scores'}), 403
        
        organization_id = user_payload['organization_id']
        
        # Get score in the same organization
        score = Score.query.filter_by(
            id=score_id,
            organization_id=organization_id
        ).first()
        
        if not score:
            return jsonify({'error': 'Score not found'}), 404
        
        data = request.get_json()
        
        # Update allowed fields
        if 'score_value' in data:
            try:
                score.score_value = int(data['score_value'])
            except ValueError:
                return jsonify({'error': 'Score value must be an integer'}), 400
        
        if 'description' in data:
            score.description = data['description']
        
        db.session.flush()
        
        # Update aggregates
        update_score_aggregate(
            user_id=score.user_id,
            group_id=score.group_id,
            category=score.category,
            organization_id=organization_id
        )
        
        db.session.commit()
        
        return jsonify({
            'message': 'Score updated successfully',
            'score': score.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/<score_id>', methods=['DELETE'])
def delete_score(score_id):
    """Delete score"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Check if user is ORG_ADMIN
        if user_payload.get('role') != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can delete scores'}), 403
        
        organization_id = user_payload['organization_id']
        
        # Get score in the same organization
        score = Score.query.filter_by(
            id=score_id,
            organization_id=organization_id
        ).first()
        
        if not score:
            return jsonify({'error': 'Score not found'}), 404
        
        # Store info for aggregate update
        user_id = score.user_id
        group_id = score.group_id
        category = score.category
        
        db.session.delete(score)
        db.session.flush()
        
        # Update aggregates
        update_score_aggregate(
            user_id=user_id,
            group_id=group_id,
            category=category,
            organization_id=organization_id
        )
        
        db.session.commit()
        
        return jsonify({
            'message': 'Score deleted successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/aggregates', methods=['GET'])
def get_aggregates():
    """Get score aggregates"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Build query with filters
        query = ScoreAggregate.query.filter_by(organization_id=organization_id)
        
        # Filter by user_id
        user_id = request.args.get('user_id')
        if user_id:
            query = query.filter_by(user_id=user_id)
        
        # Filter by group_id
        group_id = request.args.get('group_id')
        if group_id:
            query = query.filter_by(group_id=group_id)
        
        # Filter by category
        category = request.args.get('category')
        if category:
            query = query.filter_by(category=category)
        
        aggregates = query.all()
        
        return jsonify({
            'aggregates': [a.to_dict() for a in aggregates]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/user/<user_id>/total', methods=['GET'])
def get_user_total_score(user_id):
    """Get user's total score across all categories"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Get total score for user
        total = db.session.query(func.sum(Score.score_value)).filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).scalar() or 0
        
        # Get score count
        count = Score.query.filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).count()
        
        # Get average
        average = total / count if count > 0 else 0
        
        return jsonify({
            'user_id': user_id,
            'total_score': total,
            'score_count': count,
            'average_score': average
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/group/<group_id>/total', methods=['GET'])
def get_group_total_score(group_id):
    """Get group's total score across all categories"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Get total score for group
        total = db.session.query(func.sum(Score.score_value)).filter_by(
            group_id=group_id,
            organization_id=organization_id
        ).scalar() or 0
        
        # Get score count
        count = Score.query.filter_by(
            group_id=group_id,
            organization_id=organization_id
        ).count()
        
        # Get average
        average = total / count if count > 0 else 0
        
        return jsonify({
            'group_id': group_id,
            'total_score': total,
            'score_count': count,
            'average_score': average
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

