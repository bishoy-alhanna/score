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
import { CalendarIcon, UserIcon, GraduationCapIcon, PhoneIcon, MailIcon, LinkIcon, SettingsIcon, Camera, Upload, User } from "lucide-react";
import api from '../services/api';

const UserProfile = ({ organizationId }) => {
  const { t } = useTranslation();
  const [profile, setProfile] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [uploadingImage, setUploadingImage] = useState(false);
  const [imagePreview, setImagePreview] = useState(null);

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
      const response = await api.get('/users/profile', { params });
      console.log('Profile response:', response.data);
      setProfile(response.data.user || response.data);
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
      const response = await api.put('/users/profile', profile);
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

  const handleImageUpload = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      setError('Invalid file type. Please upload a JPG, PNG, GIF, or WebP image.');
      return;
    }

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      setError('File too large. Maximum size is 5MB.');
      return;
    }

    // Show preview
    const reader = new FileReader();
    reader.onload = (e) => setImagePreview(e.target.result);
    reader.readAsDataURL(file);

    // Upload file
    setUploadingImage(true);
    setError('');
    setSuccess('');

    try {
      const formData = new FormData();
      formData.append('file', file);

      console.log('Uploading profile picture...');
      const response = await api.post('/users/profile/upload-picture', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      console.log('Upload response:', response.data);

      // Update profile with new picture URL
      setProfile(prev => ({
        ...prev,
        profile_picture_url: response.data.profile_picture_url
      }));

      setSuccess('Profile picture updated successfully!');
    } catch (error) {
      console.error('Error uploading image:', error);
      console.error('Error details:', error.response || error.message);
      setError(error.response?.data?.error || error.message || 'Failed to upload image');
      setImagePreview(null);
    } finally {
      setUploadingImage(false);
      // Reset file input
      event.target.value = '';
    }
  };

  const getProfilePictureUrl = () => {
    if (imagePreview) return imagePreview;
    if (profile.profile_picture_url) {
      // Handle both relative and absolute URLs
      if (profile.profile_picture_url.startsWith('http')) {
        return profile.profile_picture_url;
      }
      return `${window.location.origin}${profile.profile_picture_url}`;
    }
    return null;
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
              {/* Profile Picture Section */}
              <div className="flex flex-col items-center space-y-4 pb-6 border-b">
                <div className="relative">
                  <div className="w-32 h-32 rounded-full overflow-hidden bg-gray-200 flex items-center justify-center border-4 border-white shadow-lg">
                    {getProfilePictureUrl() ? (
                      <img 
                        src={getProfilePictureUrl()} 
                        alt="Profile" 
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <User className="w-16 h-16 text-gray-400" />
                    )}
                  </div>
                  <label 
                    htmlFor="profile-picture-upload"
                    className={`absolute bottom-0 right-0 ${uploadingImage ? 'bg-gray-400 cursor-not-allowed' : 'bg-blue-500 hover:bg-blue-600 cursor-pointer'} text-white p-2 rounded-full transition-colors shadow-lg`}
                  >
                    {uploadingImage ? <Upload className="w-4 h-4 animate-pulse" /> : <Camera className="w-4 h-4" />}
                  </label>
                  <input
                    id="profile-picture-upload"
                    type="file"
                    accept="image/jpeg,image/jpg,image/png,image/gif,image/webp"
                    onChange={handleImageUpload}
                    className="hidden"
                    disabled={uploadingImage}
                  />
                </div>
                
                <div className="text-center">
                  <p className="text-sm font-medium text-gray-900">
                    {profile.first_name && profile.last_name 
                      ? `${profile.first_name} ${profile.last_name}` 
                      : profile.username || 'User'}
                  </p>
                  <p className="text-sm text-gray-500">
                    {uploadingImage ? 'Uploading...' : 'Click camera icon to change picture'}
                  </p>
                </div>
              </div>

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