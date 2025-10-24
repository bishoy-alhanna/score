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
        setTimeout(checkReady, 100);
      }
    };

    checkReady();
  }, [i18n]);

  if (!isReady) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-lg">Loading...</div>
      </div>
    );
  }

  return children;
};

export default TranslationWrapper;