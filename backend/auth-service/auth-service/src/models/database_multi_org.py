from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import uuid
import secrets
import bcrypt
from sqlalchemy.dialects.postgresql import UUID

db = SQLAlchemy()

class Organization(db.Model):
    __tablename__ = 'organizations'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = db.Column(db.String(255), unique=True, nullable=False)
    description = db.Column(db.Text, nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user_memberships = db.relationship('UserOrganization', backref='organization', lazy=True, cascade='all, delete-orphan')
    pending_join_requests = db.relationship('OrganizationJoinRequest', foreign_keys='OrganizationJoinRequest.organization_id', backref='organization_for_join_request', lazy=True, cascade='all, delete-orphan')
    invitations = db.relationship('OrganizationInvitation', backref='organization_for_invitation', lazy=True, cascade='all, delete-orphan')
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'name': self.name,
            'description': self.description,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'member_count': len([m for m in self.user_memberships if m.is_active]) if self.user_memberships else 0
        }

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(255), nullable=True)
    last_name = db.Column(db.String(255), nullable=True)
    profile_picture_url = db.Column(db.String(500), nullable=True)
    
    # Personal Information
    birthdate = db.Column(db.Date, nullable=True)
    phone_number = db.Column(db.String(20), nullable=True)
    bio = db.Column(db.Text, nullable=True)
    gender = db.Column(db.String(20), nullable=True)  # Male, Female, Other, Prefer not to say
    
    # Academic Information
    school_year = db.Column(db.String(50), nullable=True)  # Freshman, Sophomore, Junior, Senior, Graduate, Faculty
    student_id = db.Column(db.String(50), nullable=True)
    major = db.Column(db.String(100), nullable=True)
    gpa = db.Column(db.Float, nullable=True)
    graduation_year = db.Column(db.Integer, nullable=True)
    
    # Contact Information
    address_line1 = db.Column(db.String(255), nullable=True)
    address_line2 = db.Column(db.String(255), nullable=True)
    city = db.Column(db.String(100), nullable=True)
    state = db.Column(db.String(50), nullable=True)
    postal_code = db.Column(db.String(20), nullable=True)
    country = db.Column(db.String(100), nullable=True)
    
    # Emergency Contact
    emergency_contact_name = db.Column(db.String(255), nullable=True)
    emergency_contact_phone = db.Column(db.String(20), nullable=True)
    emergency_contact_relationship = db.Column(db.String(50), nullable=True)
    
    # Social Media & Links
    linkedin_url = db.Column(db.String(500), nullable=True)
    github_url = db.Column(db.String(500), nullable=True)
    personal_website = db.Column(db.String(500), nullable=True)
    
    # Preferences
    timezone = db.Column(db.String(50), nullable=True, default='UTC')
    language = db.Column(db.String(10), nullable=True, default='en')
    notification_preferences = db.Column(db.JSON, nullable=True)  # Store as JSON for flexibility
    
    # System fields
    is_active = db.Column(db.Boolean, default=True)
    is_verified = db.Column(db.Boolean, default=False)
    email_verified_at = db.Column(db.DateTime, nullable=True)
    last_login_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # QR Code fields
    qr_code_token = db.Column(db.String(255), unique=True, nullable=True)
    qr_code_generated_at = db.Column(db.DateTime, nullable=True)
    qr_code_expires_at = db.Column(db.DateTime, nullable=True)
    
    # Relationships
    organization_memberships = db.relationship('UserOrganization', backref='user', lazy=True, cascade='all, delete-orphan')
    submitted_join_requests = db.relationship('OrganizationJoinRequest', foreign_keys='OrganizationJoinRequest.user_id', backref='requesting_user', lazy=True, cascade='all, delete-orphan')
    
    __table_args__ = (
        db.Index('idx_user_username', 'username'),
        db.Index('idx_user_email', 'email'),
        db.Index('idx_qr_token', 'qr_code_token'),
        db.Index('idx_user_student_id', 'student_id'),
        db.Index('idx_user_school_year', 'school_year'),
        db.Index('idx_user_graduation_year', 'graduation_year'),
        db.Index('idx_user_active', 'is_active'),
    )
    
    def to_dict(self, include_organizations=False, include_sensitive=False):
        result = {
            'id': str(self.id),
            'username': self.username,
            'email': self.email,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'profile_picture_url': self.profile_picture_url,
            
            # Personal Information
            'birthdate': self.birthdate.isoformat() if self.birthdate else None,
            'phone_number': self.phone_number,
            'bio': self.bio,
            'gender': self.gender,
            
            # Academic Information
            'school_year': self.school_year,
            'student_id': self.student_id,
            'major': self.major,
            'gpa': self.gpa,
            'graduation_year': self.graduation_year,
            
            # Social Media & Links
            'linkedin_url': self.linkedin_url,
            'github_url': self.github_url,
            'personal_website': self.personal_website,
            
            # Preferences
            'timezone': self.timezone,
            'language': self.language,
            'notification_preferences': self.notification_preferences,
            
            # System fields
            'is_active': self.is_active,
            'is_verified': self.is_verified,
            'email_verified_at': self.email_verified_at.isoformat() if self.email_verified_at else None,
            'last_login_at': self.last_login_at.isoformat() if self.last_login_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'has_qr_code': bool(self.qr_code_token and self.qr_code_expires_at and self.qr_code_expires_at > datetime.utcnow())
        }
        
        # Include sensitive information only when explicitly requested
        if include_sensitive:
            result.update({
                'address_line1': self.address_line1,
                'address_line2': self.address_line2,
                'city': self.city,
                'state': self.state,
                'postal_code': self.postal_code,
                'country': self.country,
                'emergency_contact_name': self.emergency_contact_name,
                'emergency_contact_phone': self.emergency_contact_phone,
                'emergency_contact_relationship': self.emergency_contact_relationship,
            })
        
        if include_organizations:
            result['organizations'] = [
                {
                    'organization_id': str(membership.organization_id),
                    'organization_name': membership.organization.name,
                    'role': membership.role,
                    'department': membership.department,
                    'title': membership.title,
                    'joined_at': membership.joined_at.isoformat() if membership.joined_at else None,
                    'is_active': membership.is_active
                }
                for membership in self.organization_memberships if membership.is_active
            ]
        
        return result
    
    def get_role_in_organization(self, organization_id):
        """Get user's role in a specific organization"""
        membership = UserOrganization.query.filter_by(
            user_id=self.id,
            organization_id=organization_id,
            is_active=True
        ).first()
        return membership.role if membership else None
    
    def is_admin_in_organization(self, organization_id):
        """Check if user is admin in a specific organization"""
        role = self.get_role_in_organization(organization_id)
        return role in ['ORG_ADMIN', 'SUPER_ADMIN']
    
    def can_manage_organization(self, organization_id):
        """Check if user can manage a specific organization"""
        return self.is_admin_in_organization(organization_id)
    
    def get_organizations(self, active_only=True):
        """Get all organizations user belongs to"""
        query = UserOrganization.query.filter_by(user_id=self.id)
        if active_only:
            query = query.filter_by(is_active=True)
        return query.all()
    
    def verify_password(self, password):
        """Verify user password"""
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
    
    def set_password(self, password):
        """Set user password using bcrypt hashing"""
        self.password_hash = self.hash_password(password)
    
    @staticmethod
    def hash_password(password):
        """Hash password using bcrypt"""
        return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    def generate_qr_code_token(self, expires_in_hours=24):
        """Generate a new QR code token for the user"""
        self.qr_code_token = secrets.token_urlsafe(32)
        self.qr_code_generated_at = datetime.utcnow()
        self.qr_code_expires_at = datetime.utcnow() + timedelta(hours=expires_in_hours)
        return self.qr_code_token
    
    def is_qr_code_valid(self):
        """Check if the user's QR code is still valid"""
        return (self.qr_code_token and 
                self.qr_code_expires_at and 
                self.qr_code_expires_at > datetime.utcnow())

class UserOrganization(db.Model):
    __tablename__ = 'user_organizations'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    role = db.Column(db.String(50), nullable=False, default='USER')  # USER, ORG_ADMIN, SUPER_ADMIN
    department = db.Column(db.String(255), nullable=True)
    title = db.Column(db.String(255), nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        db.UniqueConstraint('user_id', 'organization_id', name='unique_user_organization'),
        db.Index('idx_user_org_user', 'user_id'),
        db.Index('idx_user_org_org', 'organization_id'),
        db.Index('idx_user_org_role', 'role'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'user_id': str(self.user_id),
            'organization_id': str(self.organization_id),
            'role': self.role,
            'department': self.department,
            'title': self.title,
            'is_active': self.is_active,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class OrganizationJoinRequest(db.Model):
    __tablename__ = 'organization_join_requests'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    requested_role = db.Column(db.String(50), default='USER')
    message = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(50), default='PENDING')  # PENDING, APPROVED, REJECTED
    reviewed_by = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=True)
    reviewed_at = db.Column(db.DateTime, nullable=True)
    review_message = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    reviewer = db.relationship('User', foreign_keys=[reviewed_by])
    
    __table_args__ = (
        db.Index('idx_join_req_user', 'user_id'),
        db.Index('idx_join_req_org', 'organization_id'),
        db.Index('idx_join_req_status', 'status'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'user_id': str(self.user_id),
            'user': self.requesting_user.to_dict() if self.requesting_user else None,
            'organization_id': str(self.organization_id),
            'organization_name': self.organization_for_join_request.name if self.organization_for_join_request else None,
            'requested_role': self.requested_role,
            'message': self.message,
            'status': self.status,
            'reviewed_by': str(self.reviewed_by) if self.reviewed_by else None,
            'reviewer': self.reviewer.to_dict() if self.reviewer else None,
            'reviewed_at': self.reviewed_at.isoformat() if self.reviewed_at else None,
            'review_message': self.review_message,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class OrganizationInvitation(db.Model):
    __tablename__ = 'organization_invitations'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    invited_by = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    email = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(50), default='USER')
    message = db.Column(db.Text, nullable=True)
    token = db.Column(db.String(255), unique=True, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    status = db.Column(db.String(50), default='PENDING')  # PENDING, ACCEPTED, EXPIRED
    accepted_by = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=True)
    accepted_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    inviter = db.relationship('User', foreign_keys=[invited_by])
    accepter = db.relationship('User', foreign_keys=[accepted_by])
    
    __table_args__ = (
        db.Index('idx_invitation_org', 'organization_id'),
        db.Index('idx_invitation_email', 'email'),
        db.Index('idx_invitation_token', 'token'),
        db.Index('idx_invitation_status', 'status'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'organization_id': str(self.organization_id),
            'organization_name': self.organization.name if self.organization else None,
            'invited_by': str(self.invited_by),
            'inviter': self.inviter.to_dict() if self.inviter else None,
            'email': self.email,
            'role': self.role,
            'message': self.message,
            'token': self.token,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'status': self.status,
            'accepted_by': str(self.accepted_by) if self.accepted_by else None,
            'accepter': self.accepter.to_dict() if self.accepter else None,
            'accepted_at': self.accepted_at.isoformat() if self.accepted_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    def is_expired(self):
        """Check if invitation is expired"""
        return datetime.utcnow() > self.expires_at
    
    @staticmethod
    def generate_token():
        """Generate a unique invitation token"""
        return secrets.token_urlsafe(32)

# Legacy models for compatibility (if needed)
class SuperAdminConfig(db.Model):
    __tablename__ = 'super_admin_config'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'username': self.username,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

# Additional models for complete functionality
class Group(db.Model):
    __tablename__ = 'groups'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    created_by = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    members = db.relationship('GroupMember', backref='group', lazy=True, cascade='all, delete-orphan')
    scores = db.relationship('Score', backref='group', lazy=True, cascade='all, delete-orphan')
    
    __table_args__ = (
        db.UniqueConstraint('name', 'organization_id', name='unique_group_name_per_org'),
        db.Index('idx_group_org', 'organization_id'),
        db.Index('idx_group_creator', 'created_by'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'name': self.name,
            'description': self.description,
            'organization_id': str(self.organization_id),
            'created_by': str(self.created_by),
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'member_count': len(self.members) if self.members else 0
        }

class GroupMember(db.Model):
    __tablename__ = 'group_members'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id = db.Column(UUID(as_uuid=True), db.ForeignKey('groups.id'), nullable=False)
    user_id = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    role = db.Column(db.String(50), default='MEMBER')  # MEMBER, ADMIN
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', backref='group_memberships')
    
    __table_args__ = (
        db.UniqueConstraint('group_id', 'user_id', name='unique_user_per_group'),
        db.Index('idx_group_member_group', 'group_id'),
        db.Index('idx_group_member_user', 'user_id'),
        db.Index('idx_group_member_org', 'organization_id'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'group_id': str(self.group_id),
            'user_id': str(self.user_id),
            'organization_id': str(self.organization_id),
            'role': self.role,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None,
            'user': self.user.to_dict() if self.user else None
        }

class Score(db.Model):
    __tablename__ = 'scores'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=True)
    group_id = db.Column(UUID(as_uuid=True), db.ForeignKey('groups.id'), nullable=True)
    score_value = db.Column(db.Integer, nullable=False)
    category = db.Column(db.String(255), default='general')
    description = db.Column(db.Text, nullable=True)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    assigned_by = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', foreign_keys=[user_id], backref='scores_received')
    assigner = db.relationship('User', foreign_keys=[assigned_by], backref='scores_assigned')
    
    __table_args__ = (
        db.CheckConstraint('(user_id IS NOT NULL AND group_id IS NULL) OR (user_id IS NULL AND group_id IS NOT NULL)', 
                          name='check_user_or_group'),
        db.Index('idx_score_user', 'user_id'),
        db.Index('idx_score_group', 'group_id'),
        db.Index('idx_score_org', 'organization_id'),
        db.Index('idx_score_category', 'category'),
        db.Index('idx_score_date', 'created_at'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'user_id': str(self.user_id) if self.user_id else None,
            'group_id': str(self.group_id) if self.group_id else None,
            'score_value': self.score_value,
            'category': self.category,
            'description': self.description,
            'organization_id': str(self.organization_id),
            'assigned_by': str(self.assigned_by),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'user': self.user.to_dict() if self.user else None,
            'assigner': self.assigner.to_dict() if self.assigner else None
        }

class QRScanLog(db.Model):
    """Log QR code scans for analytics and security"""
    __tablename__ = 'qr_scan_logs'
    
    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    scanned_user_id = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    scanner_user_id = db.Column(UUID(as_uuid=True), db.ForeignKey('users.id'), nullable=False)
    organization_id = db.Column(UUID(as_uuid=True), db.ForeignKey('organizations.id'), nullable=False)
    qr_token = db.Column(db.String(255), nullable=False)
    scan_result = db.Column(db.String(50), nullable=False)  # success, expired, invalid, unauthorized
    score_assigned = db.Column(db.Float, nullable=True)
    score_type = db.Column(db.String(50), nullable=True)  # user, group
    scan_ip = db.Column(db.String(45), nullable=True)
    user_agent = db.Column(db.Text, nullable=True)
    scanned_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    scanned_user = db.relationship('User', foreign_keys=[scanned_user_id])
    scanner_user = db.relationship('User', foreign_keys=[scanner_user_id])
    
    __table_args__ = (
        db.Index('idx_scan_user', 'scanned_user_id'),
        db.Index('idx_scan_scanner', 'scanner_user_id'),
        db.Index('idx_scan_org', 'organization_id'),
        db.Index('idx_scan_date', 'scanned_at'),
        db.Index('idx_scan_result', 'scan_result'),
    )
    
    def to_dict(self):
        return {
            'id': str(self.id),
            'scanned_user_id': str(self.scanned_user_id),
            'scanned_username': self.scanned_user.username if self.scanned_user else None,
            'scanner_user_id': str(self.scanner_user_id),
            'scanner_username': self.scanner_user.username if self.scanner_user else None,
            'organization_id': str(self.organization_id),
            'scan_result': self.scan_result,
            'score_assigned': self.score_assigned,
            'score_type': self.score_type,
            'scanned_at': self.scanned_at.isoformat() if self.scanned_at else None
        }