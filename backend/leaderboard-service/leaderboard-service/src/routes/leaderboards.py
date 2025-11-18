from flask import Blueprint, request, jsonify, current_app
import jwt
import json
import requests
import sys
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

def fetch_user_details(user_ids, auth_token):
    """Fetch user details from user service"""
    if not user_ids:
        return {}
    
    try:
        # Prepare headers
        headers = {
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json'
        }
        
        # Get user service URL from environment
        user_service_url = os.environ.get('USER_SERVICE_URL', 'http://user-service:5000')
        
        user_details = {}
        
        # Fetch each user individually (since there's no bulk endpoint)
        for user_id in user_ids:
            try:
                url = f'{user_service_url}/api/users/{user_id}'
                response = requests.get(url, headers=headers, timeout=5)
                
                if response.status_code == 200:
                    user_data = response.json().get('user', {})
                    user_details[user_id] = {
                        'first_name': user_data.get('first_name', ''),
                        'last_name': user_data.get('last_name', ''),
                        'username': user_data.get('username', ''),
                        'email': user_data.get('email', ''),
                        'profile_picture_url': user_data.get('profile_picture_url', '')
                    }
                else:
                    # Fallback for missing user
                    user_details[user_id] = {
                        'first_name': '',
                        'last_name': '',
                        'username': f'User {str(user_id)[:8]}',
                        'email': '',
                        'profile_picture_url': ''
                    }
            except Exception as e:
                # Fallback for API errors
                user_details[user_id] = {
                    'first_name': '',
                    'last_name': '',
                    'username': f'User {str(user_id)[:8]}',
                    'email': '',
                    'profile_picture_url': ''
                }
        
        return user_details
        
    except Exception as e:
        print(f"Error fetching user details: {str(e)}")
        # Return fallback data
        return {user_id: {
            'first_name': '',
            'last_name': '',
            'username': f'User {str(user_id)[:8]}',
            'email': ''
        } for user_id in user_ids}

def fetch_group_details(group_ids, auth_token):
    """Fetch group details from group service"""
    print(f"DEBUG: fetch_group_details called with group_ids: {group_ids}")
    
    if not group_ids:
        return {}
    
    try:
        # Prepare headers
        headers = {
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json'
        }
        
        # Get group service URL from environment
        group_service_url = os.environ.get('GROUP_SERVICE_URL', 'http://group-service:5003')
        
        group_details = {}
        
        # Fetch each group individually
        for group_id in group_ids:
            try:
                url = f'{group_service_url}/api/groups/{group_id}'
                response = requests.get(url, headers=headers, timeout=5)
                
                print(f"Group API call: {url}")
                print(f"Auth token first 20 chars: {auth_token[:20]}...")
                print(f"Headers: {headers}")
                print(f"Response status: {response.status_code}")
                print(f"Response body: {response.text}")
                
                if response.status_code == 200:
                    group_data = response.json().get('group', {})
                    group_details[group_id] = {
                        'name': group_data.get('name', ''),
                        'description': group_data.get('description', ''),
                        'member_count': group_data.get('member_count', 0)
                    }
                else:
                    print(f"API call failed, using fallback for group {group_id}")
                    # Fallback for missing group
                    group_details[group_id] = {
                        'name': f'Group {str(group_id)[:8]}',
                        'description': '',
                        'member_count': 0
                    }
            except Exception as e:
                # Fallback for API errors
                group_details[group_id] = {
                    'name': f'Group {str(group_id)[:8]}',
                    'description': '',
                    'member_count': 0
                }
        
        return group_details
        
    except Exception as e:
        print(f"Error fetching group details: {str(e)}")
        # Return fallback data
        return {group_id: {
            'name': f'Group {str(group_id)[:8]}',
            'description': '',
            'member_count': 0
        } for group_id in group_ids}

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
        if category == 'all':
            # Aggregate scores across all categories for each user
            from sqlalchemy import func
            user_aggregates_query = db.session.query(
                ScoreAggregate.user_id,
                func.sum(ScoreAggregate.total_score).label('total_score'),
                func.sum(ScoreAggregate.score_count).label('score_count'),
                func.avg(ScoreAggregate.average_score).label('average_score'),
                func.max(ScoreAggregate.last_updated).label('last_updated')
            ).filter_by(
                organization_id=organization_id
            ).filter(
                ScoreAggregate.user_id.isnot(None)
            ).group_by(
                ScoreAggregate.user_id
            ).order_by(
                func.sum(ScoreAggregate.total_score).desc()
            ).limit(limit)
            
            # Convert to list of objects with proper attributes
            user_aggregates = []
            for row in user_aggregates_query.all():
                # Create a mock aggregate object
                class MockAggregate:
                    def __init__(self, user_id, total_score, score_count, average_score, last_updated):
                        self.user_id = user_id
                        self.total_score = total_score or 0
                        self.score_count = score_count or 0
                        self.average_score = float(average_score) if average_score else 0.0
                        self.last_updated = last_updated
                
                user_aggregates.append(MockAggregate(
                    row.user_id, row.total_score, row.score_count, 
                    row.average_score, row.last_updated
                ))
        else:
            user_aggregates = ScoreAggregate.query.filter_by(
                organization_id=organization_id,
                category=category
        ).filter(
            ScoreAggregate.user_id.isnot(None)
        ).order_by(
            ScoreAggregate.total_score.desc()
        ).limit(limit).all()
        
        # Get user IDs for fetching details
        user_ids = [aggregate.user_id for aggregate in user_aggregates]
        
        # Fetch user details from user service
        auth_token = request.headers.get('Authorization', '').replace('Bearer ', '')
        user_details = fetch_user_details(user_ids, auth_token)
        
        # Format leaderboard with user details
        leaderboard = []
        for rank, aggregate in enumerate(user_aggregates, 1):
            user_info = user_details.get(aggregate.user_id, {})
            
            # Build display name: prefer first_name + last_name, fallback to username
            first_name = user_info.get('first_name', '').strip()
            last_name = user_info.get('last_name', '').strip()
            
            if first_name and last_name:
                display_name = f"{first_name} {last_name}"
            elif first_name:
                display_name = first_name
            elif last_name:
                display_name = last_name
            else:
                display_name = user_info.get('username', f'User {str(aggregate.user_id)[:8]}')
            
            leaderboard.append({
                'rank': rank,
                'user_id': aggregate.user_id,
                'display_name': display_name,
                'first_name': user_info.get('first_name', ''),
                'last_name': user_info.get('last_name', ''),
                'username': user_info.get('username', ''),
                'profile_picture_url': user_info.get('profile_picture_url', ''),
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
    print("DEBUG: Group leaderboard endpoint called!")
    sys.stdout.flush()
    
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        limit = int(request.args.get('limit', 50))
        
        print(f"DEBUG: Getting group leaderboard for org: {organization_id}, category: {category}")
        
        # Check cache first
        cache_key = get_cache_key(organization_id, 'groups', category)
        cached_data = get_cached_leaderboard(cache_key)
        if cached_data:
            print("DEBUG: Returning cached group leaderboard data")
            # Apply limit to cached data
            cached_data['leaderboard'] = cached_data['leaderboard'][:limit]
            return jsonify(cached_data), 200
        
        # Query database
        if category == 'all':
            # Aggregate scores across all categories for each group
            from sqlalchemy import func
            group_aggregates_query = db.session.query(
                ScoreAggregate.group_id,
                func.sum(ScoreAggregate.total_score).label('total_score'),
                func.sum(ScoreAggregate.score_count).label('score_count'),
                func.avg(ScoreAggregate.average_score).label('average_score'),
                func.max(ScoreAggregate.last_updated).label('last_updated')
            ).filter_by(
                organization_id=organization_id
            ).filter(
                ScoreAggregate.group_id.isnot(None)
            ).group_by(
                ScoreAggregate.group_id
            ).order_by(
                func.sum(ScoreAggregate.total_score).desc()
            ).limit(limit)
            
            # Convert to list of objects with proper attributes
            group_aggregates = []
            for row in group_aggregates_query.all():
                # Create a mock aggregate object
                class MockAggregate:
                    def __init__(self, group_id, total_score, score_count, average_score, last_updated):
                        self.group_id = group_id
                        self.total_score = total_score or 0
                        self.score_count = score_count or 0
                        self.average_score = float(average_score) if average_score else 0.0
                        self.last_updated = last_updated
                
                group_aggregates.append(MockAggregate(
                    row.group_id, row.total_score, row.score_count, 
                    row.average_score, row.last_updated
                ))
        else:
            group_aggregates = ScoreAggregate.query.filter_by(
                organization_id=organization_id,
                category=category
            ).filter(
                ScoreAggregate.group_id.isnot(None)
            ).order_by(
                ScoreAggregate.total_score.desc()
            ).limit(limit).all()
        
        print(f"DEBUG: Found {len(group_aggregates)} group aggregates")
        
        # Get group IDs for fetching details
        group_ids = [aggregate.group_id for aggregate in group_aggregates]
        
        print(f"DEBUG: Group IDs to fetch: {group_ids}")
        
        # Fetch group details from group service
        auth_token = request.headers.get('Authorization', '').replace('Bearer ', '')
        group_details = fetch_group_details(group_ids, auth_token)
        
        print(f"DEBUG: Fetched group details: {group_details}")
        
        # Format leaderboard with group details
        leaderboard = []
        for rank, aggregate in enumerate(group_aggregates, 1):
            group_info = group_details.get(aggregate.group_id, {})
            
            leaderboard.append({
                'rank': rank,
                'group_id': aggregate.group_id,
                'name': group_info.get('name', f'Group {str(aggregate.group_id)[:8]}'),
                'description': group_info.get('description', ''),
                'member_count': group_info.get('member_count', 0),
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

@leaderboards_bp.route('/categories', methods=['GET'])
def get_leaderboard_categories():
    """Get available score categories for leaderboards"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Get distinct categories from score aggregates
        categories = db.session.query(ScoreAggregate.category).filter_by(
            organization_id=organization_id
        ).distinct().all()
        
        # Format the response
        category_list = [category[0] for category in categories if category[0]]
        
        # Add "all" as the first option to view combined scores
        if category_list:
            category_list = ['all'] + category_list
        else:
            category_list = ['all', 'general']
        
        return jsonify({
            'categories': category_list
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

