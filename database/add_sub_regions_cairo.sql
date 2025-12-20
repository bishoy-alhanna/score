-- Migration to add sub-regions (districts/neighborhoods) for cities
-- Run this after add_cities_states_tables.sql

-- Create sub_regions table for districts/neighborhoods within cities
CREATE TABLE IF NOT EXISTS sub_regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255),
    city_id UUID REFERENCES cities(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, city_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sub_regions_city_id ON sub_regions(city_id);
CREATE INDEX IF NOT EXISTS idx_sub_regions_active ON sub_regions(is_active);

-- Create trigger for updated_at
CREATE TRIGGER update_sub_regions_updated_at BEFORE UPDATE ON sub_regions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Alter users table to include sub_region
ALTER TABLE users ADD COLUMN IF NOT EXISTS sub_region_id UUID REFERENCES sub_regions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_users_sub_region_id ON users(sub_region_id);

-- Insert sub-regions for Nasr City
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Nasr City District 1', 'الحي الأول مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 2', 'الحي الثاني مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 3', 'الحي الثالث مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 4', 'الحي الرابع مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 5', 'الحي الخامس مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 6', 'الحي السادس مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 7', 'الحي السابع مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 8', 'الحي الثامن مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 9', 'الحي التاسع مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nasr City District 10', 'الحي العاشر مدينة نصر', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Abbas El Akkad', 'عباس العقاد', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Makram Ebeid', 'مكرم عبيد', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Tayaran', 'الطيران', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'City Stars', 'سيتي ستارز', id FROM cities WHERE name = 'Nasr City' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Hadayek El-Kobba
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Deir El-Malak', 'دير الملاك', id FROM cities WHERE name = 'Hadayek El-Kobba' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Moleiha', 'المليحة', id FROM cities WHERE name = 'Hadayek El-Kobba' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Manshiet El-Sadr', 'منشية الصدر', id FROM cities WHERE name = 'Hadayek El-Kobba' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Waily', 'الويلي', id FROM cities WHERE name = 'Hadayek El-Kobba' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Saray El-Kobba', 'سراي القبة', id FROM cities WHERE name = 'Hadayek El-Kobba' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Hadayek El-Kobba Gardens', 'حدائق القبة الحدائق', id FROM cities WHERE name = 'Hadayek El-Kobba' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Heliopolis
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Korba', 'كوربا', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Roxy', 'روكسي', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Nozha', 'النزهة', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Sheraton', 'شيراتون', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Ard El-Golf', 'أرض الجولف', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Triumph', 'الترامب', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Merghany', 'المرغني', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Hegaz', 'الحجاز', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Maza', 'المازة', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Safir', 'سفير', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Qobba El-Gedida', 'القبة الجديدة', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Merryland', 'ميريلاند', id FROM cities WHERE name = 'Heliopolis' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Maadi
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Maadi Degla', 'المعادي دجلة', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Maadi Sarayat', 'المعادي السرايات', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Maadi Gardens', 'حدائق المعادي', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Maadi Grand Mall Area', 'منطقة جراند مول', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Corniche El-Maadi', 'كورنيش المعادي', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Arab Maadi', 'المعادي العربي', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Hadayek El-Maadi', 'حدائق المعادي', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Maadi Street 9', 'شارع 9 المعادي', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Zahraa El-Maadi', 'زهراء المعادي', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Wadi Degla', 'وادي دجلة', id FROM cities WHERE name = 'Maadi' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Dokki
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Mesaha Square', 'ميدان المساحة', id FROM cities WHERE name = 'Dokki' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Tahrir Street Dokki', 'شارع التحرير الدقي', id FROM cities WHERE name = 'Dokki' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Sudan Street', 'شارع السودان', id FROM cities WHERE name = 'Dokki' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Nile Street Dokki', 'شارع النيل الدقي', id FROM cities WHERE name = 'Dokki' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Batal Ahmed Abdel Aziz', 'البطل أحمد عبد العزيز', id FROM cities WHERE name = 'Dokki' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Wezaret El-Zeraa', 'وزارة الزراعة', id FROM cities WHERE name = 'Dokki' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Mohandessin
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Arab League', 'جامعة الدول العربية', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Lebanon Square', 'ميدان لبنان', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Shehab', 'شهاب', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Gamet El-Dewal', 'جامعة الدول', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Syrian Square', 'ميدان سوريا', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mohy El-Din Abu El-Ezz', 'محي الدين أبو العز', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Batal Ahmed Abdel Aziz', 'البطل أحمد عبد العزيز', id FROM cities WHERE name = 'Mohandessin' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Zamalek
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT '26th of July Street', 'شارع 26 يوليو', id FROM cities WHERE name = 'Zamalek' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Brazil Street', 'شارع البرازيل', id FROM cities WHERE name = 'Zamalek' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Shagaret El-Dor', 'شجرة الدر', id FROM cities WHERE name = 'Zamalek' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Hassan Sabry', 'حسن صبري', id FROM cities WHERE name = 'Zamalek' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Zamalek Gardens', 'حدائق الزمالك', id FROM cities WHERE name = 'Zamalek' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Gezira Club Area', 'منطقة نادي الجزيرة', id FROM cities WHERE name = 'Zamalek' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Shubra
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Rod El-Farag', 'روض الفرج', id FROM cities WHERE name = 'Shubra' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Shubra El-Balad', 'شبرا البلد', id FROM cities WHERE name = 'Shubra' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Teraa El-Boulaqia', 'الترعة البولاقية', id FROM cities WHERE name = 'Shubra' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Shubra Masr', 'شبرا مصر', id FROM cities WHERE name = 'Shubra' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Sahel', 'الساحل', id FROM cities WHERE name = 'Shubra' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Koleyet El-Zeraa', 'كلية الزراعة', id FROM cities WHERE name = 'Shubra' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Downtown Cairo
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Talaat Harb Square', 'ميدان طلعت حرب', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Abdeen', 'عابدين', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Bab El-Louk', 'باب اللوق', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mohamed Mahmoud', 'محمد محمود', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Qasr El-Nil', 'قصر النيل', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Tahrir Square', 'ميدان التحرير', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Champollion', 'شامبليون', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Adly Street', 'شارع عدلي', id FROM cities WHERE name = 'Downtown Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for New Cairo
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Fifth Settlement', 'التجمع الخامس', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'First Settlement', 'التجمع الأول', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Third Settlement', 'التجمع الثالث', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'New Cairo City Center', 'وسط القاهرة الجديدة', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Katameya Heights', 'كاتميا هايتس', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Katameya Dunes', 'كاتميا دونز', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Madinaty', 'مدينتي', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mountain View', 'ماونتن فيو', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Hyde Park', 'هايد بارك', id FROM cities WHERE name = 'New Cairo' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Abbasiya
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Abbasiya Square', 'ميدان العباسية', id FROM cities WHERE name = 'Abbasiya' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Ramses Extension', 'امتداد رمسيس', id FROM cities WHERE name = 'Abbasiya' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'El-Geish Street', 'شارع الجيش', id FROM cities WHERE name = 'Abbasiya' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Helmeyat El-Zeitoun', 'حلمية الزيتون', id FROM cities WHERE name = 'Abbasiya' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Faculty of Engineering', 'كلية الهندسة', id FROM cities WHERE name = 'Abbasiya' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Helwan
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Helwan El-Balad', 'حلوان البلد', id FROM cities WHERE name = 'Helwan' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Ain Helwan', 'عين حلوان', id FROM cities WHERE name = 'Helwan' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Maasara', 'المعصرة', id FROM cities WHERE name = 'Helwan' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT '15 May City', 'مدينة 15 مايو', id FROM cities WHERE name = 'Helwan' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Helwan University Area', 'منطقة جامعة حلوان', id FROM cities WHERE name = 'Helwan' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Kafr El-Elw', 'كفر العلو', id FROM cities WHERE name = 'Helwan' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for El-Mokattam
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Mokattam District 1', 'الحي الأول المقطم', id FROM cities WHERE name = 'El-Mokattam' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mokattam District 2', 'الحي الثاني المقطم', id FROM cities WHERE name = 'El-Mokattam' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mokattam District 3', 'الحي الثالث المقطم', id FROM cities WHERE name = 'El-Mokattam' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mokattam District 4', 'الحي الرابع المقطم', id FROM cities WHERE name = 'El-Mokattam' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Mokattam District 5', 'الحي الخامس المقطم', id FROM cities WHERE name = 'El-Mokattam' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Modern Mokattam', 'المقطم الحديث', id FROM cities WHERE name = 'El-Mokattam' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

-- Insert sub-regions for Ain Shams
INSERT INTO sub_regions (name, name_ar, city_id)
SELECT 'Ain Shams El-Sharqiya', 'عين شمس الشرقية', id FROM cities WHERE name = 'Ain Shams' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Ain Shams El-Gharbiya', 'عين شمس الغربية', id FROM cities WHERE name = 'Ain Shams' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Gesr El-Suez', 'جسر السويس', id FROM cities WHERE name = 'Ain Shams' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
UNION ALL
SELECT 'Alf Maskan', 'ألف مسكن', id FROM cities WHERE name = 'Ain Shams' AND state_id = (SELECT id FROM states WHERE name = 'Cairo')
ON CONFLICT (name, city_id) DO NOTHING;

COMMENT ON TABLE sub_regions IS 'Sub-regions/neighborhoods/districts within cities, managed by super admin';
COMMENT ON COLUMN users.sub_region_id IS 'Reference to user sub-region/neighborhood within their city';
