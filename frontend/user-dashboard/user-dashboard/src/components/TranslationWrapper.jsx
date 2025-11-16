import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';

const TranslationWrapper = ({ children }) => {
  console.log('TranslationWrapper rendering')
  const { i18n } = useTranslation();
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    console.log('TranslationWrapper useEffect - i18n.isInitialized:', i18n.isInitialized)
    
    const checkReady = () => {
      const hasResources = i18n.hasResourceBundle(i18n.language, 'translation')
      console.log('Checking i18n ready - isInitialized:', i18n.isInitialized, 'hasResources:', hasResources, 'language:', i18n.language)
      
      if (i18n.isInitialized && hasResources) {
        console.log('i18n is ready!')
        setIsReady(true);
      } else {
        setTimeout(checkReady, 50);
      }
    };
    
    // Check immediately if already initialized
    if (i18n.isInitialized) {
      console.log('i18n already initialized')
      setIsReady(true)
    } else {
      console.log('Starting i18n ready check loop')
      checkReady();
    }
  }, [i18n]);

  console.log('TranslationWrapper - isReady:', isReady)

  if (!isReady) {
    console.log('TranslationWrapper showing loading...')
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-2 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  console.log('TranslationWrapper rendering children')
  return children;
};

export default TranslationWrapper;