'use client';

import React, { useState, ChangeEvent, KeyboardEvent } from 'react';
import { Send, Upload, ChevronDown, X } from 'lucide-react';

// Définition des types
interface Message {
  type: 'user' | 'assistant';
  content: string;
  files: File[];
}

interface Model {
  id: string;
  name: string;
}

const ChatInterface = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState<string>('');
  const [selectedModel, setSelectedModel] = useState<string>('gpt-4');
  const [files, setFiles] = useState<File[]>([]);
  const [isModelDropdownOpen, setIsModelDropdownOpen] = useState<boolean>(false);

  // Couleurs Accenture - Thème sombre
  const accentureColors = {
    darkPurple: '#4B0082',  // Violet foncé principal
    deepPurple: '#2D004F',  // Violet encore plus foncé pour le fond
    lightAccent: '#8B00FF', // Accent plus clair pour les éléments interactifs
    black: '#1A0029'        // Presque noir avec une teinte violette
  };

  const models: Model[] = [
    { id: 'gpt-4', name: 'GPT-4' },
    { id: 'claude-3', name: 'Claude 3' },
    { id: 'llama-2', name: 'Llama 2' },
    { id: 'palm', name: 'PaLM' }
  ];

  const handleSendMessage = () => {
    if (inputMessage.trim() !== '') {
      const newMessage: Message = {
        type: 'user',
        content: inputMessage,
        files: [...files]
      };
      setMessages([...messages, newMessage]);
      setInputMessage('');
      setFiles([]);
    }
  };

  const handleFileUpload = (e: ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const newFiles = Array.from(e.target.files);
      setFiles([...files, ...newFiles]);
    }
  };

  const removeFile = (fileToRemove: File) => {
    setFiles(files.filter(file => file !== fileToRemove));
  };

  const handleKeyPress = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSendMessage();
    }
  };

  return (
    <div className="flex flex-col h-screen bg-[#2D004F]">
      {/* Header avec logo et branding Accenture */}
      <div className="flex justify-between items-center p-4 bg-[#4B0082]">
        <div className="flex items-center gap-6">
          <div className="flex items-center">
            <span className="text-white font-bold text-2xl">Gepetto</span>
          </div>
          <div className="relative">
            <button
              onClick={() => setIsModelDropdownOpen(!isModelDropdownOpen)}
              className="flex items-center gap-2 px-4 py-2 rounded bg-[#2D004F] text-white hover:bg-[#3D0066] transition-colors"
            >
              {selectedModel}
              <ChevronDown size={16} />
            </button>
            
            {isModelDropdownOpen && (
              <div className="absolute top-full left-0 mt-1 w-48 bg-[#4B0082] rounded shadow-lg z-10">
                {models.map((model) => (
                  <button
                    key={model.id}
                    onClick={() => {
                      setSelectedModel(model.id);
                      setIsModelDropdownOpen(false);
                    }}
                    className="block w-full text-left px-4 py-2 text-white hover:bg-[#3D0066] transition-colors"
                  >
                    {model.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
        <div className="text-white text-sm font-semibold tracking-wide">
          POWERED BY ACCENTURE TECHNOLOGY
        </div>
      </div>

      {/* Messages Container */}
      <div className="flex-grow overflow-y-auto p-4 space-y-4 bg-[#2D004F]">
        {messages.map((message, index) => (
          <div key={index} className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[70%] rounded-lg p-4 ${
              message.type === 'user' 
                ? 'bg-[#4B0082] text-white' 
                : 'bg-[#3D0066] text-white'
            }`}>
              <p>{message.content}</p>
              {message.files && message.files.length > 0 && (
                <div className="mt-2 space-y-1">
                  {message.files.map((file, fileIndex) => (
                    <div key={fileIndex} className="text-sm text-white/90 flex items-center gap-2">
                      📎 {file.name}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Files Preview */}
      {files.length > 0 && (
        <div className="px-4 py-2 bg-[#4B0082]">
          <div className="flex flex-wrap gap-2">
            {files.map((file, index) => (
              <div key={index} className="flex items-center gap-2 bg-[#3D0066] text-white px-3 py-1 rounded">
                <span className="text-sm">{file.name}</span>
                <button onClick={() => removeFile(file)} className="hover:text-white/70">
                  <X size={14} />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Input Container */}
      <div className="p-4 bg-[#4B0082]">
        <div className="flex gap-2">
          <label className="flex items-center justify-center w-10 h-10 rounded bg-[#3D0066] hover:bg-[#2D004F] transition-colors cursor-pointer">
            <input
              type="file"
              multiple
              onChange={handleFileUpload}
              className="hidden"
            />
            <Upload size={20} className="text-white" />
          </label>
          
          <input
            type="text"
            value={inputMessage}
            onChange={(e: ChangeEvent<HTMLInputElement>) => setInputMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Message Gepetto..."
            className="flex-grow px-4 py-2 rounded bg-[#2D004F] text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-[#8B00FF]"
          />
          
          <button
            onClick={handleSendMessage}
            className="flex items-center justify-center w-10 h-10 rounded bg-[#8B00FF] hover:bg-[#9B00FF] transition-colors"
          >
            <Send size={20} className="text-white" />
          </button>
        </div>
      </div>
    </div>
  );
};

export default ChatInterface;