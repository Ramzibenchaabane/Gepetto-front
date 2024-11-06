import { NextResponse } from 'next/server';
import type { GenerateRequest, ApiError } from '@/types/chat';
import { getApiUrl, getApiEndpoint } from '@/config/api';

const BACKEND_URL = `${getApiUrl()}${getApiEndpoint()}`;

async function generateResponse(prompt: string, model: string): Promise<Response> {
  console.log(`Sending request to ${BACKEND_URL} with model: ${model}, prompt: ${prompt}`);
  
  const response = await fetch(BACKEND_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: "nemotron", // Utilisation du modèle fixe "nemotron"
      prompt: prompt
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Error response:', errorText);
    throw new Error('Failed to generate response');
  }

  return response;
}

export async function POST(request: Request) {
  try {
    console.log('Received request to generate endpoint');
    
    const body = await request.json() as GenerateRequest;
    console.log('Request body:', JSON.stringify(body));
    
    if (!body.prompt) {
      return NextResponse.json({
        error: 'Prompt is required'
      } as ApiError, { status: 400 });
    }

    const response = await generateResponse(body.prompt, body.model);
    const data = await response.json();
    
    console.log('Successfully generated response');
    return NextResponse.json(data);

  } catch (error) {
    console.error('Error in generate API route:', error);
    return NextResponse.json({
      error: error instanceof Error ? error.message : 'Internal server error'
    } as ApiError, { 
      status: 500 
    });
  }
}