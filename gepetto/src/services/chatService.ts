import type { GenerateRequest, GenerateResponse, ApiError } from '@/types/chat';

class ChatService {
  static async generateResponse(model: string, prompt: string): Promise<string> {
    try {
      console.log(`Sending request for model: ${model}`);
      
      const response = await fetch('/api/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          model,
          prompt,
        } as GenerateRequest),
      });

      const data = await response.json();

      if (!response.ok) {
        // Si nous avons une réponse structurée d'erreur
        if (data.error) {
          throw new Error(data.error);
        }
        throw new Error('Failed to generate response');
      }

      return data as string;
    } catch (error) {
      console.error('Error in ChatService.generateResponse:', error);
      throw error;
    }
  }
}

export default ChatService;