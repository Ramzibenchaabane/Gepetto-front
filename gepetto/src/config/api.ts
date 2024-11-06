// src/config/api.ts

interface ApiConfig {
    BASE_URL: string;
    PORT: number;
    ENDPOINT: string;
  }
  
  const apiConfig: ApiConfig = {
    BASE_URL: process.env.NEXT_PUBLIC_API_URL || 'http://66.114.112.70',
    PORT: parseInt(process.env.NEXT_PUBLIC_API_PORT || '22186', 10),
    ENDPOINT: process.env.NEXT_PUBLIC_API_ENDPOINT || '/generate'
  };
  
  export const getApiUrl = (): string => {
    return `${apiConfig.BASE_URL}:${apiConfig.PORT}`;
  };
  
  export const getApiEndpoint = (): string => {
    return apiConfig.ENDPOINT;
  };
  
  export default apiConfig;