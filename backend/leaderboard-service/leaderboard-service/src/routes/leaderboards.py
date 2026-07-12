from flask import Blueprint, request, jsonify, current_app
import jwt
import json
import logging
import requests
from datetime import datetime
from src.models.database import db, ScoreAggregate, Score, UserOrganization
import os

leaderboards_bp = Blueprint('leaderboards', __name__)
logger = logging.getLogger(__name__)

def fetch_organization_settings(organization_id, auth_token):
    """Fetch organization settings from auth service"""
    try:
        auth_service_url = os.environ.get('AUTH_SERVICE_URL', 'http://auth-service:5000')
        headers = {
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json'
        }
        response = requests.get(
            f'{auth_service_url}/api/organizations',
            headers=headers,
            timeout=5
        )
        if response.status_code == 200:
            response_data = response.json()
            org_data = response_data.get('organization', response_data)
            return {
                'filter_enabled': org_data.get('filter_enabled', False),
                'filter_start_date': org_data.get('filter_start_date'),
                'filter_end_date': org_data.get('filter_end_date')
            }
        logger.warning('Failed to fetch org settings: status %s', response.status_code)
    except Exception as e:
        logger.error('Error fetching organization settings: %s', e)

    return {'filter_enabled': False, 'filter_start_date': None, 'filter_end_date': None}

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

    headers = {'Authorization': f'Bearer {auth_token}', 'Content-Type': 'application/json'}
    user_service_url = os.environ.get('USER_SERVICE_URL', 'http://user-service:5000')
    user_details = {}

    for user_id in user_ids:
        fallback = {'first_name': '', 'last_name': '', 'username': f'User {str(user_id)[:8]}', 'email': '', 'profile_picture_url': ''}
        try:
            response = requests.get(f'{user_service_url}/api/users/{user_id}', headers=headers, timeout=5)
            if response.status_code == 200:
                d = response.json().get('user', {})
                user_details[user_id] = {
                    'first_name': d.get('first_name') or '',
                    'last_name': d.get('last_name') or '',
                    'username': d.get('username') or '',
                    'email': d.get('email') or '',
                    'profile_picture_url': d.get('profile_picture_url') or ''
                }
            else:
                logger.warning('User fetch returned %s for user %s', response.status_code, user_id)
                user_details[user_id] = fallback
        except Exception as e:
            logger.error('Error fetching user %s: %s', user_id, e)
            user_details[user_id] = fallback

    return user_details

def fetch_group_details(group_ids, auth_token):
    """Fetch group details from group service"""
    if not group_ids:
        return {}

    headers = {'Authorization': f'Bearer {auth_token}', 'Content-Type': 'application/json'}
    group_service_url = os.environ.get('GROUP_SERVICE_URL', 'http://group-service:5003')
    group_details = {}

    for group_id in group_ids:
        fallback = {'name': f'Group {str(group_id)[:8]}', 'description': '', 'member_count': 0}
        try:
            response = requests.get(f'{group_service_url}/api/groups/{group_id}', headers=headers, timeout=5)
            if response.status_code == 200:
                d = response.json().get('group', {})
                group_details[group_id] = {
                    'name': d.get('name', ''),
                    'description': d.get('description', ''),
                    'member_count': d.get('member_count', 0)
                }
            else:
                logger.warning('Group fetch returned %s for group %s', response.status_code, group_id)
                group_details[group_id] = fallback
        except Exception as e:
            logger.error('Error fetching group %s: %s', group_id, e)
            group_details[group_id] = fallback

    return group_details

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
    """Get user leaderboard for organization with optional date range filtering"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code

        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        limit = int(request.args.get('limit', 50))

        start_date = request.args.get('start_date')  # Format: YYYY-MM-DD
        end_date = request.args.get('end_date')      # Format: YYYY-MM-DD

        # If no explicit dates provided, check organization filter settings
        if not start_date and not end_date:
            auth_token = request.headers.get('Authorization', '').replace('Bearer ', '')
            org_settings = fetch_organization_settings(organization_id, auth_token)
            if org_settings['filter_enabled']:
                start_date = org_settings['filter_start_date']
                end_date = org_settings['filter_end_date']

        if start_date or end_date:
            from sqlalchemy import func
            from datetime import timedelta

            start_dt = datetime.strptime(start_date, '%Y-%m-%d') if start_date else None
            end_dt = datetime.strptime(end_date, '%Y-%m-%d') if end_date else None
            if end_dt:
                end_dt = end_dt + timedelta(days=1)

            score_query = db.session.query(
                Score.user_id,
                func.sum(Score.score_value).label('total_score'),
                func.count(Score.id).label('score_count'),
                func.avg(Score.score_value).label('average_score'),
                func.max(Score.created_at).label('last_updated')
            ).filter_by(
                organization_id=organization_id
            ).filter(
                Score.user_id.isnot(None)
            )

            member_subquery = db.session.query(UserOrganization.user_id).filter_by(
                organization_id=organization_id,
                is_active=True
            ).subquery()
            score_query = score_query.filter(Score.user_id.in_(member_subquery))

            if start_dt:
                score_query = score_query.filter(Score.created_at >= start_dt)
            if end_dt:
                score_query = score_query.filter(Score.created_at < end_dt)

            if category != 'all':
                score_query = score_query.filter_by(category=category)

            score_query = score_query.group_by(Score.user_id).order_by(
                func.sum(Score.score_value).desc()
            ).limit(limit)

            user_aggregates = []
            for row in score_query.all():
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
            cache_key = get_cache_key(organization_id, 'users', category)
            cached_data = get_cached_leaderboard(cache_key)
            if cached_data:
                cached_data['leaderboard'] = cached_data['leaderboard'][:limit]
                return jsonify(cached_data), 200

            if category == 'all':
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

                user_aggregates = []
                for row in user_aggregates_query.all():
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

        user_ids = [aggregate.user_id for aggregate in user_aggregates]
        auth_token = request.headers.get('Authorization', '').replace('Bearer ', '')
        user_details = fetch_user_details(user_ids, auth_token)

        leaderboard = []
        for rank, aggregate in enumerate(user_aggregates, 1):
            user_info = user_details.get(aggregate.user_id, {})

            first_name = (user_info.get('first_name') or '').strip()
            last_name = (user_info.get('last_name') or '').strip()
            username = user_info.get('username') or ''

            if first_name and last_name:
                display_name = f"{first_name} {last_name}"
            elif first_name:
                display_name = first_name
            elif last_name:
                display_name = last_name
            elif username:
                display_name = username
            else:
                display_name = f'User {str(aggregate.user_id)[:8]}'

            leaderboard.append({
                'rank': rank,
                'user_id': aggregate.user_id,
                'display_name': display_name,
                'first_name': first_name,
                'last_name': last_name,
                'username': username,
                'profile_picture_url': user_info.get('profile_picture_url') or '',
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
            'total_participants': len(leaderboard),
            'start_date': start_date if start_date else None,
            'end_date': end_date if end_date else None,
            'filtered_by_date': bool(start_date or end_date)
        }

        if not (start_date or end_date):
            cache_leaderboard(cache_key, result)

        return jsonify(result), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@leaderboards_bp.route('/groups', methods=['GET'])
def get_group_leaderboard():
    """Get group leaderboard for organization with optional date range filtering"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code

        organization_id = user_payload['organization_id']
        category = request.args.get('category', 'general')
        limit = int(request.args.get('limit', 50))

        start_date = request.args.get('start_date')  # Format: YYYY-MM-DD
        end_date = request.args.get('end_date')      # Format: YYYY-MM-DD

        # If no explicit dates provided, check organization filter settings
        if not start_date and not end_date:
            auth_token = request.headers.get('Authorization', '').replace('Bearer ', '')
            org_settings = fetch_organization_settings(organization_id, auth_token)
            if org_settings['filter_enabled']:
                start_date = org_settings['filter_start_date']
                end_date = org_settings['filter_end_date']

        if start_date or end_date:
            from sqlalchemy import func, text
            from datetime import timedelta

            start_dt = datetime.strptime(start_date, '%Y-%m-%d') if start_date else None
            end_dt = datetime.strptime(end_date, '%Y-%m-%d') if end_date else None
            if end_dt:
                end_dt = end_dt + timedelta(days=1)

            direct_category_filter = ""
            direct_date_filters = ""
            if category != 'all':
                direct_category_filter = f"AND category = '{category}'"
            if start_dt:
                direct_date_filters += f" AND created_at >= '{start_dt}'"
            if end_dt:
                direct_date_filters += f" AND created_at < '{end_dt}'"

            member_category_filter = ""
            member_date_filters = ""
            if category != 'all':
                member_category_filter = f"AND s.category = '{category}'"
            if start_dt:
                member_date_filters += f" AND s.created_at >= '{start_dt}'"
            if end_dt:
                member_date_filters += f" AND s.created_at < '{end_dt}'"

            raw_query = text(f"""
                WITH direct_scores AS (
                    SELECT
                        group_id,
                        COALESCE(SUM(score_value), 0) as direct_score,
                        COUNT(id) as score_count,
                        AVG(score_value) as average_score,
                        MAX(created_at) as last_updated
                    FROM scores
                    WHERE organization_id = :org_id
                    AND group_id IS NOT NULL
                    {direct_date_filters}
                    {direct_category_filter}
                    GROUP BY group_id
                ),
                member_scores AS (
                    SELECT
                        gm.group_id,
                        COALESCE(SUM(s.score_value), 0) as member_score
                    FROM group_members gm
                    LEFT JOIN scores s ON s.user_id = gm.user_id
                        AND s.organization_id = :org_id
                        {member_date_filters}
                        {member_category_filter}
                    WHERE gm.organization_id = :org_id
                    AND gm.is_active = TRUE
                    GROUP BY gm.group_id
                ),
                all_groups AS (
                    SELECT DISTINCT group_id FROM direct_scores
                    UNION
                    SELECT DISTINCT group_id FROM member_scores
                )
                SELECT
                    ag.group_id,
                    COALESCE(ds.direct_score, 0) +
                    COALESCE(ms.member_score, 0) +
                    COALESCE(g.manual_score, 0) as total_score,
                    COALESCE(ds.score_count, 0) as score_count,
                    ds.average_score,
                    ds.last_updated
                FROM all_groups ag
                LEFT JOIN direct_scores ds ON ag.group_id = ds.group_id
                LEFT JOIN member_scores ms ON ag.group_id = ms.group_id
                LEFT JOIN groups g ON ag.group_id = g.id
                ORDER BY total_score DESC
                LIMIT :limit_val
            """)

            try:
                result = db.session.execute(raw_query, {
                    'org_id': str(organization_id),
                    'limit_val': limit
                })

                group_aggregates = []
                class MockAggregate:
                    def __init__(self, group_id, total_score, score_count, average_score, last_updated):
                        self.group_id = group_id
                        self.total_score = total_score or 0
                        self.score_count = score_count or 0
                        self.average_score = float(average_score) if average_score else 0.0
                        self.last_updated = last_updated

                for row in result:
                    group_aggregates.append(MockAggregate(
                        row.group_id, int(row.total_score), row.score_count,
                        row.average_score, row.last_updated
                    ))
            except Exception as e:
                logger.error('Failed to execute group leaderboard SQL: %s', e, exc_info=True)
                return jsonify({'error': 'Failed to fetch group leaderboard'}), 500
        else:
            cache_key = get_cache_key(organization_id, 'groups', category)
            cached_data = get_cached_leaderboard(cache_key)
            if cached_data:
                cached_data['leaderboard'] = cached_data['leaderboard'][:limit]
                return jsonify(cached_data), 200

            if category == 'all':
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

                group_aggregates = []
                for row in group_aggregates_query.all():
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

        group_ids = [aggregate.group_id for aggregate in group_aggregates]
        auth_token = request.headers.get('Authorization', '').replace('Bearer ', '')
        group_details = fetch_group_details(group_ids, auth_token)

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
            'total_participants': len(leaderboard),
            'start_date': start_date if start_date else None,
            'end_date': end_date if end_date else None,
            'filtered_by_date': bool(start_date or end_date)
        }

        if not (start_date or end_date):
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

        user_aggregate = ScoreAggregate.query.filter_by(
            user_id=user_id,
            organization_id=organization_id,
            category=category
        ).first()

        if not user_aggregate:
            return jsonify({'error': 'User not found in leaderboard'}), 404

        higher_scores = ScoreAggregate.query.filter(
            ScoreAggregate.organization_id == organization_id,
            ScoreAggregate.category == category,
            ScoreAggregate.user_id.isnot(None),
            ScoreAggregate.total_score > user_aggregate.total_score
        ).count()

        rank = higher_scores + 1

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

        group_aggregate = ScoreAggregate.query.filter_by(
            group_id=group_id,
            organization_id=organization_id,
            category=category
        ).first()

        if not group_aggregate:
            return jsonify({'error': 'Group not found in leaderboard'}), 404

        higher_scores = ScoreAggregate.query.filter(
            ScoreAggregate.organization_id == organization_id,
            ScoreAggregate.category == category,
            ScoreAggregate.group_id.isnot(None),
            ScoreAggregate.total_score > group_aggregate.total_score
        ).count()

        rank = higher_scores + 1

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

@leaderboards_bp.route('/refresh', methods=['POST'])
def refresh_leaderboard_cache():
    """Refresh leaderboard cache (ORG_ADMIN only)"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code

        if user_payload.get('role') != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can refresh cache'}), 403

        organization_id = user_payload['organization_id']

        redis_client = current_app.config.get('REDIS_CLIENT')
        if redis_client:
            try:
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

        categories = db.session.query(ScoreAggregate.category).filter_by(
            organization_id=organization_id
        ).distinct().all()

        category_list = [category[0] for category in categories if category[0]]

        if category_list:
            category_list = ['all'] + category_list
        else:
            category_list = ['all', 'general']

        return jsonify({
            'categories': category_list
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
