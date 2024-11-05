// types/chat.ts

export interface Message {
    id: string;
    type: 'user' | 'assistant';
    content: string;
    files: File[];
    timestamp: Date;
  }
  
  export interface Model {
    id: string;
    name: string;
    description: string;
  }
  
  export interface GenerateRequest {
    model: string;
    prompt: string;
  }
  
  export interface GenerateResponse {
    content: string;
    error?: string;
  }
  
  export interface ApiError {
    error: string;
    details?: unknown;
  }