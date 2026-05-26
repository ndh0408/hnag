'use client';

import * as React from 'react';
import { Search, Mic } from 'lucide-react';
import { Input } from './input';

interface SearchBarProps {
  placeholder?: string;
  voice?: boolean;
  onVoiceClick?: () => void;
  value?: string;
  onChange?: React.ChangeEventHandler<HTMLInputElement>;
}

export function SearchBar({ placeholder = 'Tìm món, quán...', voice = true, onVoiceClick, value, onChange }: SearchBarProps) {
  return (
    <Input
      leading={<Search />}
      placeholder={placeholder}
      value={value}
      onChange={onChange}
      trailing={
        voice && (
          <button
            type="button"
            onClick={onVoiceClick}
            className="size-7 rounded-full bg-brand-50 dark:bg-brand-500/20 inline-flex items-center justify-center text-brand-500"
            aria-label="Voice search"
          >
            <Mic className="size-3.5" />
          </button>
        )
      }
    />
  );
}
