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
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Ajuste automatiquement la hauteur du textarea
  const adjustTextareaHeight = () => {
    const textarea = textareaRef.current;
    if (textarea) {
      textarea.style.height = 'inherit';
      const computed = window.getComputedStyle(textarea);
      const height = parseInt(computed.getPropertyValue('border-top-width'), 10)
                   + parseInt(computed.getPropertyValue('padding-top'), 10)
                   + textarea.scrollHeight
                   + parseInt(computed.getPropertyValue('padding-bottom'), 10)
                   + parseInt(computed.getPropertyValue('border-bottom-width'), 10);

      textarea.style.height = `${Math.min(height, 150)}px`; // Maximum height: 150px
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setInputMessage(e.target.value);
    adjustTextareaHeight();
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

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
    if (textareaRef.current) {
      textareaRef.current.style.height = 'inherit';
    }

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
        <Image 
          src={GpettoLogo} 
          alt="Gpetto Logo" 
          className={styles.logo}
          width={180}
          height={50}
          priority
        />

        <Image 
          src={AccentureLogo} 
          alt="Accenture Logo" 
          className={styles['accenture-logo']}
          width={200}
          height={50}
          priority
        />

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

      {/* Messages area */}
      <div className={styles['messages-container']}>
        {/* Left column */}
        <div className={styles['messages-left']}>
          {messages.filter(m => m.type === 'user').map((message) => (
            <div key={message.id} className={`${styles['message-item']} ${styles.fadeIn}`}>
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

        {/* Right column */}
        <div className={styles['messages-right']}>
          {messages.filter(m => m.type === 'assistant').map((message) => (
            <div key={message.id} className={`${styles['assistant-message']} ${styles.fadeIn}`}>
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
          {isLoading && (
            <div className={`${styles['assistant-message']} ${styles.fadeIn}`}>
              <div className={styles['message-header']}>
                <span>Gpetto :</span>
              </div>
              <p className={`${styles['message-content']} ${styles.thinking}`}>
                I&apos;m thinking...
              </p>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Input area */}
      <div className={styles['input-container']}>
        <div className={styles['input-wrapper']}>
          <textarea
            ref={textareaRef}
            value={inputMessage}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            placeholder="Type your question here"
            className={styles.input}
            rows={1}
          />
          <button
            onClick={handleSendMessage}
            className={styles['send-button']}
            disabled={isLoading}
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