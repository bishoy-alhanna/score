from flask import Blueprint, request, jsonify, current_app
import jwt
import json
from src.models.database import db, ScoreAggregate
import os

leaderboards_bp = Blueprint('leaderboards', __name__)

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

def get_cache_key(organization_id, leaderboard_type, category='general'):
    """Generate cache key for leaderboard"""
    return f"leaderboard:{organization_id}:{leaderboard_type}:{category}"

def cache_leaderboard(key, data, ttl=300):
    """Cache leaderboard data in Redis"""
    redis_client = current_app.config.get('REDIS_CLIENT')
    if redis_client:
        try:
            redis_client.setex(key, ttl, json.dumps(data))
        except:
            pass  # Fail silently if Redis is unavailable

def get_cached_leaderboard(key):
    """Get cached leaderboard data from Redis"""
    redis_client = current_app.config.get('REDIS_CLIENT')
    if redis_client:
        try:
            cached_data = redis_client.get(key)
            if cached_data:
                return json.loads(cached_data)
        except:
            pass  # Fail silently if Redis is unavailable
    return None

@leaderboards_bp.route('/users', methods=['GET'])
def get_user_leaderboard():
    """Get user leaderboard for organization"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        limit = int(request.args.get('limit', 50))
        
        # Check cache first
        cache_key = get_cache_key(organization_id, 'users', category)
        cached_data = get_cached_leaderboard(cache_key)
        if cached_data:
            # Apply limit to cached data
            cached_data['leaderboard'] = cached_data['leaderboard'][:limit]
            return jsonify(cached_data), 200
        
        # Query database
        user_aggregates = ScoreAggregate.query.filter_by(
            organization_id=organization_id,
            category=category
        ).filter(
            ScoreAggregate.user_id.isnot(None)
        ).order_by(
            ScoreAggregate.total_score.desc()
        ).limit(limit).all()
        
        # Format leaderboard
        leaderboard = []
        for rank, aggregate in enumerate(user_aggregates, 1):
            leaderboard.append({
                'rank': rank,
                'user_id': aggregate.user_id,
                'total_score': aggregate.total_score,
                'score_count': aggregate.score_count,
                'average_score': aggregate.average_score,
                'last_updated': aggregate.last_updated.isoformat() if aggregate.last_updated else None
            })
        
        result = {
            'leaderboard_type': 'users',
            'category': category,
            'organization_id': organization_id,
            'leaderboard': leaderboard,
            'total_participants': len(leaderboard)
        }
        
        # Cache the result
        cache_leaderboard(cache_key, result)
        
        return jsonify(result), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@leaderboards_bp.route('/groups', methods=['GET'])
def get_group_leaderboard():
    """Get group leaderboard for organization"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        limit = int(request.args.get('limit', 50))
        
        # Check cache first
        cache_key = get_cache_key(organization_id, 'groups', category)
        cached_data = get_cached_leaderboard(cache_key)
        if cached_data:
            # Apply limit to cached data
            cached_data['leaderboard'] = cached_data['leaderboard'][:limit]
            return jsonify(cached_data), 200
        
        # Query database
        group_aggregates = ScoreAggregate.query.filter_by(
            organization_id=organization_id,
            category=category
        ).filter(
            ScoreAggregate.group_id.isnot(None)
        ).order_by(
            ScoreAggregate.total_score.desc()
        ).limit(limit).all()
        
        # Format leaderboard
        leaderboard = []
        for rank, aggregate in enumerate(group_aggregates, 1):
            leaderboard.append({
                'rank': rank,
                'group_id': aggregate.group_id,
                'total_score': aggregate.total_score,
                'score_count': aggregate.score_count,
                'average_score': aggregate.average_score,
                'last_updated': aggregate.last_updated.isoformat() if aggregate.last_updated else None
            })
        
        result = {
            'leaderboard_type': 'groups',
            'category': category,
            'organization_id': organization_id,
            'leaderboard': leaderboard,
            'total_participants': len(leaderboard)
        }
        
        # Cache the result
        cache_leaderboard(cache_key, result)
        
        return jsonify(result), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@leaderboards_bp.route('/user/<user_id>/rank', methods=['GET'])
def get_user_rank(user_id):
    """Get specific user's rank in leaderboard"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        
        # Get user's aggregate
        user_aggregate = ScoreAggregate.query.filter_by(
            user_id=user_id,
            organization_id=organization_id,
            category=category
        ).first()
        
        if not user_aggregate:
            return jsonify({'error': 'User not found in leaderboard'}), 404
        
        # Count users with higher scores
        higher_scores = ScoreAggregate.query.filter(
            ScoreAggregate.organization_id == organization_id,
            ScoreAggregate.category == category,
            ScoreAggregate.user_id.isnot(None),
            ScoreAggregate.total_score > user_aggregate.total_score
        ).count()
        
        rank = higher_scores + 1
        
        # Get total participants
        total_participants = ScoreAggregate.query.filter(
            ScoreAggregate.organization_id == organization_id,
            ScoreAggregate.category == category,
            ScoreAggregate.user_id.isnot(None)
        ).count()
        
        return jsonify({
            'user_id': user_id,
            'rank': rank,
            'total_score': user_aggregate.total_score,
            'score_count': user_aggregate.score_count,
            'average_score': user_aggregate.average_score,
            'total_participants': total_participants,
            'category': category
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@leaderboards_bp.route('/group/<group_id>/rank', methods=['GET'])
def get_group_rank(group_id):
    """Get specific group's rank in leaderboard"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        
        # Get group's aggregate
        group_aggregate = ScoreAggregate.query.filter_by(
            group_id=group_id,
            organization_id=organization_id,
            category=category
        ).first()
        
        if not group_aggregate:
            return jsonify({'error': 'Group not found in leaderboard'}), 404
        
        # Count groups with higher scores
        higher_scores = ScoreAggregate.query.filter(
            ScoreAggregate.organization_id == organization_id,
            ScoreAggregate.category == category,
            ScoreAggregate.group_id.isnot(None),
            ScoreAggregate.total_score > group_aggregate.total_score
        ).count()
        
        rank = higher_scores + 1
        
        # Get total participants
        total_participants = ScoreAggregate.query.filter(
            ScoreAggregate.organization_id == organization_id,
            ScoreAggregate.category == category,
            ScoreAggregate.group_id.isnot(None)
        ).count()
        
        return jsonify({
            'group_id': group_id,
            'rank': rank,
            'total_score': group_aggregate.total_score,
            'score_count': group_aggregate.score_count,
            'average_score': group_aggregate.average_score,
            'total_participants': total_participants,
            'category': category
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@leaderboards_bp.route('/categories', methods=['GET'])
def get_categories():
    """Get all scoring categories for organization"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Get distinct categories
        categories = db.session.query(ScoreAggregate.category).filter_by(
            organization_id=organization_id
        ).distinct().all()
        
        category_list = [cat[0] for cat in categories]
        
        return jsonify({
            'categories': category_list
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@leaderboards_bp.route('/refresh', methods=['POST'])
def refresh_leaderboard_cache():
    """Refresh leaderboard cache (ORG_ADMIN only)"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Check if user is ORG_ADMIN
        if user_payload.get('role') != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can refresh cache'}), 403
        
        organization_id = user_payload['organization_id']
        
        # Clear cache for this organization
        redis_client = current_app.config.get('REDIS_CLIENT')
        if redis_client:
            try:
                # Get all cache keys for this organization
                pattern = f"leaderboard:{organization_id}:*"
                keys = redis_client.keys(pattern)
                if keys:
                    redis_client.delete(*keys)
            except:
                pass  # Fail silently if Redis is unavailable
        
        return jsonify({
            'message': 'Leaderboard cache refreshed successfully'
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

