from flask import Blueprint, request, jsonify
import jwt
from src.models.database import db, Score, ScoreAggregate, ScoreCategory
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

@scores_bp.route('', methods=['POST'])
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
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        if not data.get('score_value'):
            return jsonify({'error': 'Score value is required'}), 400
        
        if not data.get('user_id') and not data.get('group_id'):
            return jsonify({'error': 'Either user_id or group_id is required'}), 400
        
        if data.get('user_id') and data.get('group_id'):
            return jsonify({'error': 'Cannot assign score to both user and group'}), 400
        
        score_value = data['score_value']
        user_id = data.get('user_id')
        group_id = data.get('group_id')
        category_id = data.get('category_id')
        category = data.get('category', 'general')  # Backward compatibility
        description = data.get('description', '')
        organization_id = data.get('organization_id') or user_payload['organization_id']
        assigned_by = user_payload['user_id']
        
        # If category_id is provided, use it; otherwise fall back to category string
        if category_id:
            # Validate category exists and belongs to organization
            score_category = ScoreCategory.query.filter_by(
                id=category_id,
                organization_id=organization_id,
                is_active=True
            ).first()
            
            if not score_category:
                return jsonify({'error': 'Invalid category ID'}), 400
            
            # Validate score doesn't exceed max
            if score_value > score_category.max_score:
                return jsonify({
                    'error': f'Score value cannot exceed maximum of {score_category.max_score} for this category'
                }), 400
        
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
            category_id=category_id,
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

@scores_bp.route('', methods=['GET'])
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
        
        # DEBUG: Print what we're filtering by
        print(f"DEBUG SCORING: Getting scores for user_id: {user_id}, organization_id: {organization_id}")
        
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

# Score Categories endpoints
@scores_bp.route('/categories', methods=['GET'])
def get_score_categories():
    """Get all score categories for an organization"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = request.args.get('organization_id') or user_payload.get('organization_id')
        if not organization_id:
            return jsonify({'error': 'Organization ID required'}), 400
        
        categories = ScoreCategory.query.filter_by(
            organization_id=organization_id,
            is_active=True
        ).all()
        
        return jsonify({
            'categories': [cat.to_dict() for cat in categories]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/categories', methods=['POST'])
def create_score_category():
    """Create a new score category"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        data = request.get_json()
        name = data.get('name')
        description = data.get('description', '')
        max_score = data.get('max_score', 100)
        organization_id = data.get('organization_id') or user_payload.get('organization_id')
        
        if not name or not organization_id:
            return jsonify({'error': 'Name and organization ID are required'}), 400
        
        # Check if category already exists
        existing = ScoreCategory.query.filter_by(
            name=name,
            organization_id=organization_id
        ).first()
        
        if existing:
            return jsonify({'error': 'Category with this name already exists'}), 400
        
        category = ScoreCategory(
            name=name,
            description=description,
            max_score=max_score,
            organization_id=organization_id,
            created_by=user_payload['user_id']
        )
        
        db.session.add(category)
        db.session.commit()
        
        return jsonify({
            'message': 'Score category created successfully',
            'category': category.to_dict()
        }), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/categories/<category_id>', methods=['PUT'])
def update_score_category(category_id):
    """Update a score category"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        category = ScoreCategory.query.get_or_404(category_id)
        
        # Check if user has permission to update
        # Allow if: same organization OR user is org admin (role check)
        user_org_id = user_payload.get('organization_id')
        user_role = user_payload.get('role', 'USER')
        
        # Check organization match (convert both to strings to handle UUID vs string comparison)
        if str(category.organization_id) != str(user_org_id):
            # Only ORG_ADMIN or super admin can modify categories from other orgs
            if user_role not in ['ORG_ADMIN', 'SUPER_ADMIN'] and not user_payload.get('is_super_admin', False):
                return jsonify({'error': 'Permission denied'}), 403
        
        data = request.get_json()
        
        if 'name' in data:
            category.name = data['name']
        if 'description' in data:
            category.description = data['description']
        if 'max_score' in data:
            category.max_score = data['max_score']
        if 'is_predefined' in data:
            category.is_predefined = data['is_predefined']
        
        db.session.commit()
        
        return jsonify({
            'message': 'Score category updated successfully',
            'category': category.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/categories/<category_id>', methods=['DELETE'])
def delete_score_category(category_id):
    """Delete a score category"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        category = ScoreCategory.query.get_or_404(category_id)
        
        # Check if user has permission to delete
        # Allow if: same organization OR user is org admin (role check)
        user_org_id = user_payload.get('organization_id')
        user_role = user_payload.get('role', 'USER')
        
        # Check organization match (convert both to strings to handle UUID vs string comparison)
        if str(category.organization_id) != str(user_org_id):
            # Only ORG_ADMIN or super admin can delete categories from other orgs
            if user_role not in ['ORG_ADMIN', 'SUPER_ADMIN'] and not user_payload.get('is_super_admin', False):
                return jsonify({'error': 'Permission denied'}), 403
        
        # Soft delete (org admins can delete any category including predefined ones)
        category.is_active = False
        db.session.commit()
        
        return jsonify({
            'message': 'Score category deleted successfully'
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@scores_bp.route('/user/<user_id>/weekly-by-category', methods=['GET'])
def get_user_weekly_scores_by_category(user_id):
    """Get user's weekly scores grouped by category"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        weeks_back = int(request.args.get('weeks', 6))
        
        # Get all categories for this organization
        categories = ScoreCategory.query.filter_by(
            organization_id=organization_id,
            is_active=True
        ).all()
        
        if not categories:
            return jsonify({
                'user_id': user_id,
                'organization_id': organization_id,
                'categories': [],
                'weekly_data': [],
                'weeks_back': weeks_back
            }), 200
        
        # Get all scores for this user in this organization
        from datetime import datetime, timedelta, timezone
        from sqlalchemy import and_
        
        # Calculate date range for weeks (use UTC timezone)
        end_date = datetime.now(timezone.utc)
        start_date = end_date - timedelta(weeks=weeks_back)
        
        scores = Score.query.filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).filter(
            Score.created_at >= start_date
        ).order_by(Score.created_at.asc()).all()
        
        # Group scores by week and category
        weekly_data = []
        category_names = [cat.name for cat in categories]
        
        for week_num in range(weeks_back):
            week_start = start_date + timedelta(weeks=week_num)
            week_end = week_start + timedelta(weeks=1)
            
            week_data = {'week': f'Week {week_num + 1}'}
            
            # Initialize all categories with 0
            for cat_name in category_names:
                week_data[cat_name] = 0
            
            # Calculate scores for this week
            week_scores = [s for s in scores if week_start <= s.created_at < week_end]
            
            for score in week_scores:
                # Get category name from relationship or fallback to category field
                cat_name = score.score_category.name if score.score_category else score.category
                if cat_name and cat_name in week_data:
                    week_data[cat_name] += score.score_value
            
            weekly_data.append(week_data)
        
        return jsonify({
            'user_id': user_id,
            'organization_id': organization_id,
            'categories': category_names,
            'weekly_data': weekly_data,
            'weeks_back': weeks_back
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@scores_bp.route('/create-predefined-categories', methods=['POST'])
def create_predefined_categories():
    """Create predefined categories for a new organization"""
    try:
        data = request.get_json()
        
        organization_id = data.get('organization_id')
        created_by = data.get('created_by')
        
        if not organization_id or not created_by:
            return jsonify({'error': 'organization_id and created_by are required'}), 400
        
        # Define predefined categories in Arabic
        predefined_categories = [
            {
                'name': 'القداس',
                'description': 'حضور القداس',
                'max_score': 100
            },
            {
                'name': 'التناول',
                'description': 'تناول القربان المقدس',
                'max_score': 100
            },
            {
                'name': 'الاعتراف',
                'description': 'سر الاعتراف',
                'max_score': 100
            }
        ]
        
        created_categories = []
        
        for cat_data in predefined_categories:
            # Check if category already exists
            existing = ScoreCategory.query.filter_by(
                name=cat_data['name'],
                organization_id=organization_id
            ).first()
            
            if not existing:
                category = ScoreCategory(
                    name=cat_data['name'],
                    description=cat_data['description'],
                    max_score=cat_data['max_score'],
                    organization_id=organization_id,
                    created_by=created_by,
                    is_predefined=True
                )
                
                db.session.add(category)
                created_categories.append(cat_data['name'])
        
        db.session.commit()
        
        return jsonify({
            'message': 'Predefined categories created successfully',
            'created_categories': created_categories
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@scores_bp.route('/user/<user_id>/check-score', methods=['GET'])
def check_user_score_exists(user_id):
    """Check if user has a score for a specific category and date"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Users can only check their own scores unless they're admin
        if user_payload['user_id'] != user_id and user_payload.get('role') not in ['ADMIN', 'ORG_ADMIN']:
            return jsonify({'error': 'Permission denied'}), 403
            
        category_id = request.args.get('category_id')
        date_str = request.args.get('date')  # Expected format: YYYY-MM-DD
        
        if not category_id or not date_str:
            return jsonify({'error': 'category_id and date are required'}), 400
        
        try:
            from datetime import datetime
            date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
        
        # Check if score exists for this user, category, and date
        existing_score = Score.query.filter(
            Score.user_id == user_id,
            Score.category_id == category_id,
            func.date(Score.created_at) == date_obj,
            Score.organization_id == user_payload['organization_id']
        ).first()
        
        return jsonify({
            'exists': existing_score is not None,
            'score_id': str(existing_score.id) if existing_score else None,
            'score_value': existing_score.score_value if existing_score else None
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@scores_bp.route('/user/<user_id>/self-report', methods=['POST'])
def self_report_score(user_id):
    """Allow user to self-report score for predefined categories"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Users can only report for themselves
        if user_payload['user_id'] != user_id:
            return jsonify({'error': 'You can only report scores for yourself'}), 403
        
        data = request.get_json()
        category_id = data.get('category_id')
        date_str = data.get('date')  # Expected format: YYYY-MM-DD
        
        if not category_id or not date_str:
            return jsonify({'error': 'category_id and date are required'}), 400
        
        try:
            from datetime import datetime
            date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
        
        # Get the category and verify it's predefined
        category = ScoreCategory.query.filter_by(
            id=category_id,
            organization_id=user_payload['organization_id'],
            is_active=True
        ).first()
        
        if not category:
            return jsonify({'error': 'Category not found'}), 404
        
        if not getattr(category, 'is_predefined', False):
            return jsonify({'error': 'Self-reporting is only allowed for predefined categories'}), 400
        
        # Check if score already exists for this date
        existing_score = Score.query.filter(
            Score.user_id == user_id,
            Score.category_id == category_id,
            func.date(Score.created_at) == date_obj,
            Score.organization_id == user_payload['organization_id']
        ).first()
        
        if existing_score:
            return jsonify({'error': f'You already have a score for {category.name} on {date_str}'}), 400
        
        # Create score with maximum value for the category
        score = Score(
            user_id=user_id,
            score_value=category.max_score,
            category_id=category_id,
            category=category.name,  # Backward compatibility
            description=f'Self-reported for {date_str}',
            organization_id=user_payload['organization_id'],
            assigned_by=user_id,  # Self-assigned
            created_at=datetime.combine(date_obj, datetime.min.time())
        )
        
        db.session.add(score)
        db.session.flush()
        
        # Update aggregates
        update_score_aggregate(
            user_id=user_id,
            category=category.name,
            organization_id=user_payload['organization_id']
        )
        
        db.session.commit()
        
        return jsonify({
            'message': f'Score recorded successfully for {category.name}',
            'score': score.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

