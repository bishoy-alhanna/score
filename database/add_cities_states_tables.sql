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

-- Insert Egyptian governorates with Arabic and English names
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
    ('South Sinai', 'جنوب سيناء', 'Egypt'),
    ('Kafr El-Sheikh', 'كفر الشيخ', 'Egypt')
ON CONFLICT (name) DO NOTHING;

-- Insert comprehensive cities for Cairo with Arabic and English names
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
SELECT 'Downtown Cairo', 'وسط البلد', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'New Cairo', 'القاهرة الجديدة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT '6th of October', 'السادس من أكتوبر', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Shorouk', 'الشروق', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Rehab', 'الرحاب', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Ain Shams', 'عين شمس', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Hadayek El-Kobba', 'حدائق القبة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Abbasiya', 'العباسية', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Manial', 'المنيل', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Garden City', 'جاردن سيتي', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Ghamra', 'الغمرة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Sayeda Zeinab', 'السيدة زينب', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Dar El Salam', 'دار السلام', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Basateen', 'البساتين', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'El-Matareya', 'المطرية', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'El-Zeitoun', 'الزيتون', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Helwan', 'حلوان', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'El-Khalifa', 'الخليفة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'El-Mokattam', 'المقطم', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'New Maadi', 'المعادي الجديدة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Tagamoa', 'التجمع الخامس', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Shoubra El-Kheima', 'شبرا الخيمة', id FROM states WHERE name = 'Cairo'
UNION ALL
SELECT 'Obour City', 'مدينة العبور', id FROM states WHERE name = 'Cairo'
ON CONFLICT (name, state_id) DO NOTHING;

-- Insert cities for Alexandria with Arabic and English names
INSERT INTO cities (name, name_ar, state_id)
SELECT 'Montaza', 'المنتزه', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Sidi Gaber', 'سيدي جابر', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Smouha', 'سموحة', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Miami', 'ميامي', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Mandara', 'المندرة', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Sidi Bishr', 'سيدي بشر', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Sporting', 'سبورتنج', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Stanley', 'ستانلي', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Roushdy', 'رشدي', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Glim', 'جليم', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Ibrahimiya', 'الإبراهيمية', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Camp Shezar', 'كامب شيزار', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Bakos', 'باكوس', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Cleopatra', 'كليوباترا', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'San Stefano', 'سان ستيفانو', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Kafr Abdo', 'كفر عبده', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Moharam Bek', 'محرم بك', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Agami', 'العجمي', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Borg El Arab', 'برج العرب', id FROM states WHERE name = 'Alexandria'
UNION ALL
SELECT 'Amreya', 'العامرية', id FROM states WHERE name = 'Alexandria'
ON CONFLICT (name, state_id) DO NOTHING;

-- Insert cities for Giza with Arabic and English names
INSERT INTO cities (name, name_ar, state_id)
SELECT 'Dokki', 'الدقي', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Mohandessin', 'المهندسين', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Agouza', 'العجوزة', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Haram', 'الهرم', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Faisal', 'فيصل', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT '6th of October City', 'مدينة 6 أكتوبر', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Sheikh Zayed', 'الشيخ زايد', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Imbaba', 'إمبابة', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Boulaq El Dakrour', 'بولاق الدكرور', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Kit Kat', 'كيت كات', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Omraneya', 'العمرانية', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Hadayek El Ahram', 'حدائق الأهرام', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Pyramids', 'الأهرام', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Saft El Laban', 'صفط اللبن', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Ard El Lewa', 'أرض اللواء', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Nahya', 'الناهية', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Warraq', 'الوراق', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Manial Shiha', 'منيال شيحة', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Badrashein', 'البدرشين', id FROM states WHERE name = 'Giza'
UNION ALL
SELECT 'Awsim', 'أوسيم', id FROM states WHERE name = 'Giza'
ON CONFLICT (name, state_id) DO NOTHING;

COMMENT ON TABLE states IS 'States/Governorates managed by super admin';
COMMENT ON TABLE cities IS 'Cities managed by super admin, belongs to states';
