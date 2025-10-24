import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';

const TranslationWrapper = ({ children }) => {
  const { i18n } = useTranslation();
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    const checkReady = () => {
      if (i18n.isInitialized && i18n.hasResourceBundle(i18n.language, 'translation')) {
        setIsReady(true);
      } else {
        setTimeout(checkReady, 50);
      }
    };
    
    checkReady();
  }, [i18n]);

  if (!isReady) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-2 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return children;
};

export default TranslationWrapper;