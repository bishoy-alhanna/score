"""
Location management routes (cities and states)
Only accessible by super admin
"""
from flask import Blueprint, request, jsonify
from sqlalchemy import text
from src.models.database import db
from src.utils.auth import verify_token_and_get_user
from functools import wraps

locations_bp = Blueprint('locations', __name__, url_prefix='/locations')

def super_admin_required(f):
    """Decorator to require super admin access"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        if not user_payload.get('is_super_admin', False):
            return jsonify({'error': 'Super admin access required'}), 403
        
        return f(*args, **kwargs)
    return decorated_function

# ==================== STATES ROUTES ====================

@locations_bp.route('/states', methods=['GET'])
def get_states():
    """Get all states (public endpoint)"""
    try:
        is_active = request.args.get('is_active', 'true').lower() == 'true'
        
        query = text("""
            SELECT id, name, name_ar, country, is_active, created_at, updated_at
            FROM states
            WHERE is_active = :is_active
            ORDER BY name
        """)
        
        result = db.session.execute(query, {'is_active': is_active})
        states = []
        for row in result:
            states.append({
                'id': str(row.id),
                'name': row.name,
                'name_ar': row.name_ar,
                'country': row.country,
                'is_active': row.is_active,
                'created_at': row.created_at.isoformat() if row.created_at else None,
                'updated_at': row.updated_at.isoformat() if row.updated_at else None
            })
        
        return jsonify({'states': states}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/states', methods=['POST'])
@super_admin_required
def create_state():
    """Create a new state (super admin only)"""
    try:
        data = request.get_json()
        name = data.get('name')
        name_ar = data.get('name_ar', '')
        country = data.get('country', 'Egypt')
        
        if not name:
            return jsonify({'error': 'State name is required'}), 400
        
        # Check if state already exists
        check_query = text("SELECT id FROM states WHERE name = :name")
        existing = db.session.execute(check_query, {'name': name}).first()
        
        if existing:
            return jsonify({'error': 'State already exists'}), 400
        
        # Insert new state
        insert_query = text("""
            INSERT INTO states (name, name_ar, country)
            VALUES (:name, :name_ar, :country)
            RETURNING id, name, name_ar, country, is_active, created_at
        """)
        
        result = db.session.execute(insert_query, {
            'name': name,
            'name_ar': name_ar,
            'country': country
        })
        db.session.commit()
        
        row = result.first()
        state = {
            'id': str(row.id),
            'name': row.name,
            'name_ar': row.name_ar,
            'country': row.country,
            'is_active': row.is_active,
            'created_at': row.created_at.isoformat() if row.created_at else None
        }
        
        return jsonify({
            'message': 'State created successfully',
            'state': state
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/states/<state_id>', methods=['PUT'])
@super_admin_required
def update_state(state_id):
    """Update a state (super admin only)"""
    try:
        data = request.get_json()
        
        # Build update query dynamically based on provided fields
        updates = []
        params = {'state_id': state_id}
        
        if 'name' in data:
            updates.append("name = :name")
            params['name'] = data['name']
        
        if 'name_ar' in data:
            updates.append("name_ar = :name_ar")
            params['name_ar'] = data['name_ar']
        
        if 'country' in data:
            updates.append("country = :country")
            params['country'] = data['country']
        
        if 'is_active' in data:
            updates.append("is_active = :is_active")
            params['is_active'] = data['is_active']
        
        if not updates:
            return jsonify({'error': 'No fields to update'}), 400
        
        query = text(f"""
            UPDATE states
            SET {', '.join(updates)}
            WHERE id = :state_id
            RETURNING id, name, name_ar, country, is_active, updated_at
        """)
        
        result = db.session.execute(query, params)
        db.session.commit()
        
        row = result.first()
        if not row:
            return jsonify({'error': 'State not found'}), 404
        
        state = {
            'id': str(row.id),
            'name': row.name,
            'name_ar': row.name_ar,
            'country': row.country,
            'is_active': row.is_active,
            'updated_at': row.updated_at.isoformat() if row.updated_at else None
        }
        
        return jsonify({
            'message': 'State updated successfully',
            'state': state
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/states/<state_id>', methods=['DELETE'])
@super_admin_required
def delete_state(state_id):
    """Delete a state (super admin only) - soft delete by setting is_active=false"""
    try:
        query = text("""
            UPDATE states
            SET is_active = false
            WHERE id = :state_id
            RETURNING id
        """)
        
        result = db.session.execute(query, {'state_id': state_id})
        db.session.commit()
        
        if not result.first():
            return jsonify({'error': 'State not found'}), 404
        
        return jsonify({'message': 'State deleted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== CITIES ROUTES ====================

@locations_bp.route('/cities', methods=['GET'])
def get_cities():
    """Get all cities, optionally filtered by state"""
    try:
        state_id = request.args.get('state_id')
        is_active = request.args.get('is_active', 'true').lower() == 'true'
        
        if state_id:
            query = text("""
                SELECT c.id, c.name, c.name_ar, c.state_id, c.is_active, 
                       c.created_at, c.updated_at,
                       s.name as state_name, s.name_ar as state_name_ar
                FROM cities c
                LEFT JOIN states s ON c.state_id = s.id
                WHERE c.state_id = :state_id AND c.is_active = :is_active
                ORDER BY c.name
            """)
            result = db.session.execute(query, {'state_id': state_id, 'is_active': is_active})
        else:
            query = text("""
                SELECT c.id, c.name, c.name_ar, c.state_id, c.is_active,
                       c.created_at, c.updated_at,
                       s.name as state_name, s.name_ar as state_name_ar
                FROM cities c
                LEFT JOIN states s ON c.state_id = s.id
                WHERE c.is_active = :is_active
                ORDER BY c.name
            """)
            result = db.session.execute(query, {'is_active': is_active})
        
        cities = []
        for row in result:
            cities.append({
                'id': str(row.id),
                'name': row.name,
                'name_ar': row.name_ar,
                'state_id': str(row.state_id) if row.state_id else None,
                'state_name': row.state_name,
                'state_name_ar': row.state_name_ar,
                'is_active': row.is_active,
                'created_at': row.created_at.isoformat() if row.created_at else None,
                'updated_at': row.updated_at.isoformat() if row.updated_at else None
            })
        
        return jsonify({'cities': cities}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/cities', methods=['POST'])
@super_admin_required
def create_city():
    """Create a new city (super admin only)"""
    try:
        data = request.get_json()
        name = data.get('name')
        name_ar = data.get('name_ar', '')
        state_id = data.get('state_id')
        
        if not name or not state_id:
            return jsonify({'error': 'City name and state ID are required'}), 400
        
        # Check if city already exists in this state
        check_query = text("""
            SELECT id FROM cities 
            WHERE name = :name AND state_id = :state_id
        """)
        existing = db.session.execute(check_query, {
            'name': name,
            'state_id': state_id
        }).first()
        
        if existing:
            return jsonify({'error': 'City already exists in this state'}), 400
        
        # Insert new city
        insert_query = text("""
            INSERT INTO cities (name, name_ar, state_id)
            VALUES (:name, :name_ar, :state_id)
            RETURNING id, name, name_ar, state_id, is_active, created_at
        """)
        
        result = db.session.execute(insert_query, {
            'name': name,
            'name_ar': name_ar,
            'state_id': state_id
        })
        db.session.commit()
        
        row = result.first()
        city = {
            'id': str(row.id),
            'name': row.name,
            'name_ar': row.name_ar,
            'state_id': str(row.state_id),
            'is_active': row.is_active,
            'created_at': row.created_at.isoformat() if row.created_at else None
        }
        
        return jsonify({
            'message': 'City created successfully',
            'city': city
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/cities/<city_id>', methods=['PUT'])
@super_admin_required
def update_city(city_id):
    """Update a city (super admin only)"""
    try:
        data = request.get_json()
        
        # Build update query dynamically
        updates = []
        params = {'city_id': city_id}
        
        if 'name' in data:
            updates.append("name = :name")
            params['name'] = data['name']
        
        if 'name_ar' in data:
            updates.append("name_ar = :name_ar")
            params['name_ar'] = data['name_ar']
        
        if 'state_id' in data:
            updates.append("state_id = :state_id")
            params['state_id'] = data['state_id']
        
        if 'is_active' in data:
            updates.append("is_active = :is_active")
            params['is_active'] = data['is_active']
        
        if not updates:
            return jsonify({'error': 'No fields to update'}), 400
        
        query = text(f"""
            UPDATE cities
            SET {', '.join(updates)}
            WHERE id = :city_id
            RETURNING id, name, name_ar, state_id, is_active, updated_at
        """)
        
        result = db.session.execute(query, params)
        db.session.commit()
        
        row = result.first()
        if not row:
            return jsonify({'error': 'City not found'}), 404
        
        city = {
            'id': str(row.id),
            'name': row.name,
            'name_ar': row.name_ar,
            'state_id': str(row.state_id) if row.state_id else None,
            'is_active': row.is_active,
            'updated_at': row.updated_at.isoformat() if row.updated_at else None
        }
        
        return jsonify({
            'message': 'City updated successfully',
            'city': city
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/cities/<city_id>', methods=['DELETE'])
@super_admin_required
def delete_city(city_id):
    """Delete a city (super admin only) - soft delete"""
    try:
        query = text("""
            UPDATE cities
            SET is_active = false
            WHERE id = :city_id
            RETURNING id
        """)
        
        result = db.session.execute(query, {'city_id': city_id})
        db.session.commit()
        
        if not result.first():
            return jsonify({'error': 'City not found'}), 404
        
        return jsonify({'message': 'City deleted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== SUB-REGIONS ROUTES ====================

@locations_bp.route('/sub-regions', methods=['GET'])
def get_sub_regions():
    """Get all sub-regions, optionally filtered by city"""
    try:
        city_id = request.args.get('city_id')
        is_active = request.args.get('is_active', 'true').lower() == 'true'
        
        if city_id:
            query = text("""
                SELECT sr.id, sr.name, sr.name_ar, sr.city_id, sr.is_active,
                       sr.created_at, sr.updated_at,
                       c.name as city_name, c.name_ar as city_name_ar
                FROM sub_regions sr
                LEFT JOIN cities c ON sr.city_id = c.id
                WHERE sr.city_id = :city_id AND sr.is_active = :is_active
                ORDER BY sr.name
            """)
            result = db.session.execute(query, {'city_id': city_id, 'is_active': is_active})
        else:
            query = text("""
                SELECT sr.id, sr.name, sr.name_ar, sr.city_id, sr.is_active,
                       sr.created_at, sr.updated_at,
                       c.name as city_name, c.name_ar as city_name_ar
                FROM sub_regions sr
                LEFT JOIN cities c ON sr.city_id = c.id
                WHERE sr.is_active = :is_active
                ORDER BY sr.name
            """)
            result = db.session.execute(query, {'is_active': is_active})
        
        sub_regions = []
        for row in result:
            sub_regions.append({
                'id': str(row.id),
                'name': row.name,
                'name_ar': row.name_ar,
                'city_id': str(row.city_id) if row.city_id else None,
                'city_name': row.city_name,
                'city_name_ar': row.city_name_ar,
                'is_active': row.is_active,
                'created_at': row.created_at.isoformat() if row.created_at else None,
                'updated_at': row.updated_at.isoformat() if row.updated_at else None
            })
        
        return jsonify({'sub_regions': sub_regions}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/sub-regions', methods=['POST'])
@super_admin_required
def create_sub_region():
    """Create a new sub-region (super admin only)"""
    try:
        data = request.get_json()
        name = data.get('name')
        name_ar = data.get('name_ar', '')
        city_id = data.get('city_id')
        
        if not name or not city_id:
            return jsonify({'error': 'Sub-region name and city ID are required'}), 400
        
        # Check if sub-region already exists in this city
        check_query = text("""
            SELECT id FROM sub_regions 
            WHERE name = :name AND city_id = :city_id
        """)
        existing = db.session.execute(check_query, {
            'name': name,
            'city_id': city_id
        }).first()
        
        if existing:
            return jsonify({'error': 'Sub-region already exists in this city'}), 400
        
        # Insert new sub-region
        insert_query = text("""
            INSERT INTO sub_regions (name, name_ar, city_id)
            VALUES (:name, :name_ar, :city_id)
            RETURNING id, name, name_ar, city_id, is_active, created_at
        """)
        
        result = db.session.execute(insert_query, {
            'name': name,
            'name_ar': name_ar,
            'city_id': city_id
        })
        db.session.commit()
        
        row = result.first()
        sub_region = {
            'id': str(row.id),
            'name': row.name,
            'name_ar': row.name_ar,
            'city_id': str(row.city_id),
            'is_active': row.is_active,
            'created_at': row.created_at.isoformat() if row.created_at else None
        }
        
        return jsonify({
            'message': 'Sub-region created successfully',
            'sub_region': sub_region
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/sub-regions/<sub_region_id>', methods=['PUT'])
@super_admin_required
def update_sub_region(sub_region_id):
    """Update a sub-region (super admin only)"""
    try:
        data = request.get_json()
        
        # Build update query dynamically
        updates = []
        params = {'sub_region_id': sub_region_id}
        
        if 'name' in data:
            updates.append("name = :name")
            params['name'] = data['name']
        
        if 'name_ar' in data:
            updates.append("name_ar = :name_ar")
            params['name_ar'] = data['name_ar']
        
        if 'city_id' in data:
            updates.append("city_id = :city_id")
            params['city_id'] = data['city_id']
        
        if 'is_active' in data:
            updates.append("is_active = :is_active")
            params['is_active'] = data['is_active']
        
        if not updates:
            return jsonify({'error': 'No fields to update'}), 400
        
        query = text(f"""
            UPDATE sub_regions
            SET {', '.join(updates)}
            WHERE id = :sub_region_id
            RETURNING id, name, name_ar, city_id, is_active, updated_at
        """)
        
        result = db.session.execute(query, params)
        db.session.commit()
        
        row = result.first()
        if not row:
            return jsonify({'error': 'Sub-region not found'}), 404
        
        sub_region = {
            'id': str(row.id),
            'name': row.name,
            'name_ar': row.name_ar,
            'city_id': str(row.city_id) if row.city_id else None,
            'is_active': row.is_active,
            'updated_at': row.updated_at.isoformat() if row.updated_at else None
        }
        
        return jsonify({
            'message': 'Sub-region updated successfully',
            'sub_region': sub_region
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@locations_bp.route('/sub-regions/<sub_region_id>', methods=['DELETE'])
@super_admin_required
def delete_sub_region(sub_region_id):
    """Delete a sub-region (super admin only) - soft delete"""
    try:
        query = text("""
            UPDATE sub_regions
            SET is_active = false
            WHERE id = :sub_region_id
            RETURNING id
        """)
        
        result = db.session.execute(query, {'sub_region_id': sub_region_id})
        db.session.commit()
        
        if not result.first():
            return jsonify({'error': 'Sub-region not found'}), 404
        
        return jsonify({'message': 'Sub-region deleted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
