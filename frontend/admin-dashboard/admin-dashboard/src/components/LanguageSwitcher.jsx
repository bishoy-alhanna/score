import React, { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Languages } from 'lucide-react';

const LanguageSwitcher = () => {
  const { i18n, t, ready } = useTranslation();

  const changeLanguage = (lng) => {
    i18n.changeLanguage(lng);
    // Set the document direction based on language
    document.dir = lng === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = lng;
    
    // Add/remove RTL class to body
    if (lng === 'ar') {
      document.body.classList.add('rtl');
    } else {
      document.body.classList.remove('rtl');
    }
  };

  // Set initial direction when component mounts
  useEffect(() => {
    const currentLang = i18n.language || 'en';
    document.dir = currentLang === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = currentLang;
    
    if (currentLang === 'ar') {
      document.body.classList.add('rtl');
    } else {
      document.body.classList.remove('rtl');
    }
  }, [i18n.language]);

  const currentLanguage = i18n.language || 'en';

  if (!ready) {
    return <div className="w-[120px] h-8 bg-gray-200 animate-pulse rounded"></div>;
  }

  return (
    <div className="flex items-center space-x-2 rtl:space-x-reverse">
      <Languages className="h-4 w-4" />
      <Select value={currentLanguage} onValueChange={changeLanguage}>
        <SelectTrigger className="w-[120px]">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="en">English</SelectItem>
          <SelectItem value="ar">العربية</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
};

export default LanguageSwitcher;