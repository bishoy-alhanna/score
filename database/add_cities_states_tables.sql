-- Migration to add cities and states tables managed by super admin
-- Run this on production database

-- Create states table
CREATE TABLE IF NOT EXISTS states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    name_ar VARCHAR(255),
    country VARCHAR(100) DEFAULT 'Egypt',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create cities table
CREATE TABLE IF NOT EXISTS cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255),
    state_id UUID REFERENCES states(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, state_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_cities_state_id ON cities(state_id);
CREATE INDEX IF NOT EXISTS idx_cities_active ON cities(is_active);
CREATE INDEX IF NOT EXISTS idx_states_active ON states(is_active);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_states_updated_at BEFORE UPDATE ON states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cities_updated_at BEFORE UPDATE ON cities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Alter users table to use foreign keys for city and state
-- First, backup existing data
ALTER TABLE users ADD COLUMN IF NOT EXISTS city_id UUID REFERENCES cities(id) ON DELETE SET NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS state_id UUID REFERENCES states(id) ON DELETE SET NULL;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_users_city_id ON users(city_id);
CREATE INDEX IF NOT EXISTS idx_users_state_id ON users(state_id);

-- Insert some common Egyptian states as initial data
INSERT INTO states (name, name_ar, country) VALUES
    ('Cairo', 'القاهرة', 'Egypt'),
    ('Alexandria', 'الإسكندرية', 'Egypt'),
    ('Giza', 'الجيزة', 'Egypt'),
    ('Qalyubia', 'القليوبية', 'Egypt'),
    ('Port Said', 'بورسعيد', 'Egypt'),
    ('Suez', 'السويس', 'Egypt'),
    ('Damietta', 'دمياط', 'Egypt'),
    ('Dakahlia', 'الدقهلية', 'Egypt'),
    ('Sharqia', 'الشرقية', 'Egypt'),
    ('Gharbia', 'الغربية', 'Egypt'),
    ('Monufia', 'المنوفية', 'Egypt'),
    ('Beheira', 'البحيرة', 'Egypt'),
    ('Ismailia', 'الإسماعيلية', 'Egypt'),
    ('Faiyum', 'الفيوم', 'Egypt'),
    ('Beni Suef', 'بني سويف', 'Egypt'),
    ('Minya', 'المنيا', 'Egypt'),
    ('Assiut', 'أسيوط', 'Egypt'),
    ('Sohag', 'سوهاج', 'Egypt'),
    ('Qena', 'قنا', 'Egypt'),
    ('Aswan', 'أسوان', 'Egypt'),
    ('Luxor', 'الأقصر', 'Egypt'),
    ('Red Sea', 'البحر الأحمر', 'Egypt'),
    ('New Valley', 'الوادي الجديد', 'Egypt'),
    ('Matrouh', 'مطروح', 'Egypt'),
    ('North Sinai', 'شمال سيناء', 'Egypt'),
    ('South Sinai', 'جنوب سيناء', 'Egypt')
ON CONFLICT (name) DO NOTHING;

-- Insert some common cities for Cairo as example
INSERT INTO cities (name, name_ar, state_id) 
SELECT 'Nasr City', 'مدينة نصر', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Heliopolis', 'مصر الجديدة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Maadi', 'المعادي', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Zamalek', 'الزمالك', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Dokki', 'الدقي', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Mohandessin', 'المهندسين', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Shubra', 'شبرا', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Downtown', 'وسط البلد', id FROM states WHERE name = 'Cairo'
ON CONFLICT (name, state_id) DO NOTHING;

COMMENT ON TABLE states IS 'States/Governorates managed by super admin';
COMMENT ON TABLE cities IS 'Cities managed by super admin, belongs to states';
