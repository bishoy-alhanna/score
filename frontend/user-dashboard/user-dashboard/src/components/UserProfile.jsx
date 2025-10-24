import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { CalendarIcon, UserIcon, GraduationCapIcon, PhoneIcon, MailIcon, LinkIcon, SettingsIcon } from "lucide-react";
import api from '../services/api';

const UserProfile = ({ organizationId }) => {
  const { t } = useTranslation();
  const [profile, setProfile] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const getSchoolYearOptions = () => [
    { value: 'year1', label: t('profile.year1') },
    { value: 'year2', label: t('profile.year2') },
    { value: 'year3', label: t('profile.year3') },
    { value: 'year4', label: t('profile.year4') },
    { value: 'year5', label: t('profile.year5') },
    { value: 'graduated', label: t('profile.graduated') }
  ];

  const genderOptions = [
    'Male', 'Female', 'Non-binary', 'Prefer not to say', 'Other'
  ];

  const timezoneOptions = [
    'UTC', 'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles',
    'Europe/London', 'Europe/Paris', 'Europe/Berlin', 'Asia/Tokyo', 'Asia/Shanghai'
  ];

  useEffect(() => {
    fetchProfile();
  }, [organizationId]);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      console.log('Fetching profile...');
      const params = organizationId ? { organization_id: organizationId } : {};
      const response = await api.get('/profile/me', { params });
      console.log('Profile response:', response.data);
      setProfile(response.data);
    } catch (error) {
      console.error('Error fetching profile:', error);
      setError(`${t('profile.failedToLoad')}: ${error.response?.data?.error || error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError('');
      setSuccess('');

      console.log('Saving profile data:', profile);
      const response = await api.put('/profile/me', profile);
      console.log('Save response:', response.data);
      setProfile(response.data.user || response.data);
      setSuccess(t('profile.profileUpdated'));
    } catch (error) {
      console.error('Error saving profile:', error);
      setError(error.response?.data?.error || t('profile.failedToUpdate'));
    } finally {
      setSaving(false);
    }
  };

  const handleInputChange = (field, value) => {
    setProfile(prev => ({
      ...prev,
      [field]: value
    }));
  };

  if (loading) {
    return <div className="flex justify-center p-8">Loading profile...</div>;
  }

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <UserIcon className="h-5 w-5" />
            {t('profile.title')}
          </CardTitle>
          <CardDescription>
            {t('profile.managePersonalInfo')}
          </CardDescription>
        </CardHeader>
      </Card>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert className="border-green-200 bg-green-50">
          <AlertDescription className="text-green-800">{success}</AlertDescription>
        </Alert>
      )}

      <Tabs defaultValue="personal" className="space-y-6">
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="personal">{t('profile.personal')}</TabsTrigger>
          <TabsTrigger value="academic">{t('profile.academic')}</TabsTrigger>
          <TabsTrigger value="contact">{t('profile.contact')}</TabsTrigger>
          <TabsTrigger value="social">{t('profile.social')}</TabsTrigger>
          <TabsTrigger value="preferences">{t('profile.preferences')}</TabsTrigger>
        </TabsList>

        <TabsContent value="personal" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>{t('profile.personalInfo')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="first_name">{t('profile.firstName')}</Label>
                  <Input
                    id="first_name"
                    value={profile.first_name || ''}
                    onChange={(e) => handleInputChange('first_name', e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="last_name">{t('profile.lastName')}</Label>
                  <Input
                    id="last_name"
                    value={profile.last_name || ''}
                    onChange={(e) => handleInputChange('last_name', e.target.value)}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="birthdate">{t('profile.birthdate')}</Label>
                  <Input
                    id="birthdate"
                    type="date"
                    value={profile.birthdate || ''}
                    onChange={(e) => handleInputChange('birthdate', e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="gender">{t('profile.gender')}</Label>
                  <Select
                    value={profile.gender || ''}
                    onValueChange={(value) => handleInputChange('gender', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('profile.selectGender')} />
                    </SelectTrigger>
                    <SelectContent>
                      {genderOptions.map((option) => (
                        <SelectItem key={option} value={option}>
                          {option}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="phone_number">{t('profile.phoneNumber')}</Label>
                <Input
                  id="phone_number"
                  type="tel"
                  value={profile.phone_number || ''}
                  onChange={(e) => handleInputChange('phone_number', e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="bio">{t('profile.bio')}</Label>
                <Textarea
                  id="bio"
                  rows={3}
                  value={profile.bio || ''}
                  onChange={(e) => handleInputChange('bio', e.target.value)}
                  placeholder={t('profile.tellUsAboutYourself')}
                />
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="academic" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <GraduationCapIcon className="h-5 w-5" />
                {t('profile.academicInfo')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="university_name">{t('profile.universityName')}</Label>
                <Input
                  id="university_name"
                  value={profile.university_name || ''}
                  onChange={(e) => handleInputChange('university_name', e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="faculty_name">{t('profile.facultyName')}</Label>
                <Input
                  id="faculty_name"
                  value={profile.faculty_name || ''}
                  onChange={(e) => handleInputChange('faculty_name', e.target.value)}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="school_year">{t('profile.schoolYear')}</Label>
                  <Select
                    value={profile.school_year || ''}
                    onValueChange={(value) => handleInputChange('school_year', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('profile.selectSchoolYear')} />
                    </SelectTrigger>
                    <SelectContent>
                      {getSchoolYearOptions().map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="graduation_year">{t('profile.graduationYear')}</Label>
                  <Input
                    id="graduation_year"
                    type="number"
                    min="2015"
                    max="2030"
                    value={profile.graduation_year || ''}
                    onChange={(e) => handleInputChange('graduation_year', parseInt(e.target.value) || null)}
                  />
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="contact" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <MailIcon className="h-5 w-5" />
                {t('profile.contactInfo')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="address_line1">{t('profile.addressLine1')}</Label>
                <Input
                  id="address_line1"
                  value={profile.address_line1 || ''}
                  onChange={(e) => handleInputChange('address_line1', e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="address_line2">{t('profile.addressLine2')}</Label>
                <Input
                  id="address_line2"
                  value={profile.address_line2 || ''}
                  onChange={(e) => handleInputChange('address_line2', e.target.value)}
                />
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="city">{t('profile.city')}</Label>
                  <Input
                    id="city"
                    value={profile.city || ''}
                    onChange={(e) => handleInputChange('city', e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="state">{t('profile.stateProvince')}</Label>
                  <Input
                    id="state"
                    value={profile.state || ''}
                    onChange={(e) => handleInputChange('state', e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="postal_code">{t('profile.postalCode')}</Label>
                  <Input
                    id="postal_code"
                    value={profile.postal_code || ''}
                    onChange={(e) => handleInputChange('postal_code', e.target.value)}
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="country">{t('profile.country')}</Label>
                <Input
                  id="country"
                  value={profile.country || ''}
                  onChange={(e) => handleInputChange('country', e.target.value)}
                />
              </div>

              <div className="border-t pt-4">
                <h4 className="font-semibold mb-3">{t('profile.emergencyContact')}</h4>
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="emergency_contact_name">{t('profile.emergencyContactName')}</Label>
                    <Input
                      id="emergency_contact_name"
                      value={profile.emergency_contact_name || ''}
                      onChange={(e) => handleInputChange('emergency_contact_name', e.target.value)}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="emergency_contact_phone">{t('profile.emergencyContactPhone')}</Label>
                      <Input
                        id="emergency_contact_phone"
                        type="tel"
                        value={profile.emergency_contact_phone || ''}
                        onChange={(e) => handleInputChange('emergency_contact_phone', e.target.value)}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="emergency_contact_relationship">{t('profile.relationship')}</Label>
                      <Input
                        id="emergency_contact_relationship"
                        value={profile.emergency_contact_relationship || ''}
                        onChange={(e) => handleInputChange('emergency_contact_relationship', e.target.value)}
                        placeholder={t('profile.relationshipPlaceholder')}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="social" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <LinkIcon className="h-5 w-5" />
                {t('profile.socialMediaLinks')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="linkedin_url">{t('profile.linkedinProfile')}</Label>
                <Input
                  id="linkedin_url"
                  type="url"
                  value={profile.linkedin_url || ''}
                  onChange={(e) => handleInputChange('linkedin_url', e.target.value)}
                  placeholder={t('profile.linkedinPlaceholder')}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="github_url">{t('profile.githubProfile')}</Label>
                <Input
                  id="github_url"
                  type="url"
                  value={profile.github_url || ''}
                  onChange={(e) => handleInputChange('github_url', e.target.value)}
                  placeholder={t('profile.githubPlaceholder')}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="personal_website">{t('profile.personalWebsite')}</Label>
                <Input
                  id="personal_website"
                  type="url"
                  value={profile.personal_website || ''}
                  onChange={(e) => handleInputChange('personal_website', e.target.value)}
                  placeholder={t('profile.websitePlaceholder')}
                />
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="preferences" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <SettingsIcon className="h-5 w-5" />
                {t('profile.userPreferences')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="timezone">{t('profile.timezone')}</Label>
                  <Select
                    value={profile.timezone || 'UTC'}
                    onValueChange={(value) => handleInputChange('timezone', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('profile.selectTimezone')} />
                    </SelectTrigger>
                    <SelectContent>
                      {timezoneOptions.map((tz) => (
                        <SelectItem key={tz} value={tz}>
                          {tz}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="language">{t('profile.language')}</Label>
                  <Select
                    value={profile.language || 'en'}
                    onValueChange={(value) => handleInputChange('language', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('profile.selectLanguage')} />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="en">English</SelectItem>
                      <SelectItem value="es">Spanish</SelectItem>
                      <SelectItem value="fr">French</SelectItem>
                      <SelectItem value="de">German</SelectItem>
                      <SelectItem value="zh">Chinese</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      <div className="flex justify-end space-x-4">
        <Button variant="outline" onClick={fetchProfile}>
          {t('profile.reset')}
        </Button>
        <Button onClick={handleSave} disabled={saving}>
          {saving ? t('profile.saving') : t('profile.saveChanges')}
        </Button>
      </div>
    </div>
  );
};

export default UserProfile;