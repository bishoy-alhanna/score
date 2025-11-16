import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';

const TranslationWrapper = ({ children }) => {
  const { i18n } = useTranslation();
  const [isReady, setIsReady] = useState(false);

  console.log('TranslationWrapper rendering')

  useEffect(() => {
    console.log('TranslationWrapper useEffect - i18n.isInitialized:', i18n.isInitialized)
    
    const checkReady = () => {
      const hasResources = i18n.hasResourceBundle(i18n.language, 'translation')
      console.log('Checking i18n ready - isInitialized:', i18n.isInitialized, 
                  'hasResources:', hasResources, 'language:', i18n.language)
      
      if (i18n.isInitialized && hasResources) {
        console.log('i18n is ready!')
        setIsReady(true);
      } else {
        setTimeout(checkReady, 50);
      }
    };

    // Check immediately if already initialized
    if (i18n.isInitialized) {
      console.log('i18n already initialized, setting ready immediately')
      setIsReady(true)
    } else {
      checkReady();
    }
  }, [i18n]);

  console.log('TranslationWrapper - isReady:', isReady)

  if (!isReady) {
    console.log('TranslationWrapper showing loading...')
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-lg">Loading...</div>
      </div>
    );
  }

  console.log('TranslationWrapper rendering children')
  return children;
};

export default TranslationWrapper;