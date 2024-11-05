'use client';

import React, { useState, useRef, useEffect } from 'react';
import type { Message, Model } from '@/types/chat';
import { v4 as uuidv4 } from 'uuid';
import styles from './chat.module.css';
import GpettoLogo from '@/static/img/Gpetto-logo.png';
import AccentureLogo from '@/static/img/accenture-powered-by-logo.png';
import SendButton from '@/static/img/send-button.png';
import Image from 'next/image';

const ChatInterface = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState<string>('');
  const [selectedModel, setSelectedModel] = useState<string>('Nemotron');
  const [isModelDropdownOpen, setIsModelDropdownOpen] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSendMessage = async () => {
    if (inputMessage.trim() === '' || isLoading) return;

    setIsLoading(true);
    const userMessage: Message = {
      id: uuidv4(),
      type: 'user',
      content: inputMessage,
      files: [],
      timestamp: new Date()
    };
    
    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');

    try {
      const response = await fetch('/api/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: selectedModel,
          prompt: inputMessage,
        }),
      });

      const data = await response.json();
      
      const assistantMessage: Message = {
        id: uuidv4(),
        type: 'assistant',
        content: data.response,
        files: [],
        timestamp: new Date()
      };
      
      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      {/* Header */}
      <div className={styles.header}>
        {/* Logo Gpetto */}
        <Image 
          src={GpettoLogo} 
          alt="Gpetto Logo" 
          className={styles.logo}
          width={180}
          height={50}
          priority
        />

        {/* Logo Accenture */}
        <Image 
          src={AccentureLogo} 
          alt="Accenture Logo" 
          className={styles['accenture-logo']}
          width={200}
          height={50}
          priority
        />

        {/* Sélecteur de modèle */}
        <button 
          className={styles['model-button']}
          onClick={() => setIsModelDropdownOpen(!isModelDropdownOpen)}
        >
          <span>Nemotron</span>
          <svg width="12" height="12" viewBox="0 0 12 12" className="text-white ml-2">
            <path d="M2 4L6 8L10 4" stroke="currentColor" fill="none"/>
          </svg>
        </button>
      </div>

      {/* Zone des messages */}
      <div className={styles['messages-container']}>
        {/* Colonne de gauche */}
        <div className={styles['messages-left']}>
          {messages.filter(m => m.type === 'user').map((message) => (
            <div key={message.id} className={styles['message-item']}>
              <div className={styles['message-header']}>
                <span>User : {message.content}</span>
                <span>{message.timestamp.toLocaleString('fr-FR', { 
                  hour: '2-digit', 
                  minute: '2-digit',
                  day: '2-digit',
                  month: '2-digit',
                  year: 'numeric'
                })}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Colonne de droite */}
        <div className={styles['messages-right']}>
          {messages.filter(m => m.type === 'assistant').map((message) => (
            <div key={message.id} className={styles['assistant-message']}>
              <div className={styles['message-header']}>
                <span>Gpetto :</span>
                <span>{message.timestamp.toLocaleString('fr-FR', { 
                  hour: '2-digit', 
                  minute: '2-digit',
                  day: '2-digit',
                  month: '2-digit',
                  year: 'numeric'
                })}</span>
              </div>
              <p className={styles['message-content']}>{message.content}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Zone de saisie */}
      <div className={styles['input-container']}>
        <div className={styles['input-wrapper']}>
          <input
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            placeholder="Type your question here"
            className={styles.input}
          />
          <button
            onClick={handleSendMessage}
            className={styles['send-button']}
          >
            <Image 
              src={SendButton} 
              alt="Send" 
              width={32}
              height={32}
              priority
            />
          </button>
        </div>
      </div>
    </div>
  );
};

export default ChatInterface;