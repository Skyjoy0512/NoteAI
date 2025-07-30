-- NoteAI Database Schema for GRDB.swift
-- Migration: Initial schema creation

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    project_description TEXT,
    cover_image_data BLOB,
    metadata BLOB,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Recordings table
CREATE TABLE IF NOT EXISTS recordings (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    audio_file_url TEXT NOT NULL,
    audio_quality TEXT NOT NULL,
    duration REAL NOT NULL DEFAULT 0.0,
    transcription TEXT,
    transcription_method TEXT NOT NULL,
    whisper_model TEXT,
    language TEXT NOT NULL DEFAULT 'ja',
    is_from_limitless INTEGER NOT NULL DEFAULT 0,
    metadata BLOB,
    project_id TEXT REFERENCES projects(id),
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Recording segments table
CREATE TABLE IF NOT EXISTS recording_segments (
    id TEXT PRIMARY KEY,
    recording_id TEXT NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    start_time REAL NOT NULL,
    end_time REAL NOT NULL,
    confidence REAL,
    speaker TEXT
);

-- Tags table
CREATE TABLE IF NOT EXISTS tags (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    color TEXT NOT NULL DEFAULT 'blue'
);

-- Project tags junction table
CREATE TABLE IF NOT EXISTS project_tags (
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, tag_id)
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY,
    subscription_type TEXT NOT NULL DEFAULT 'free',
    plan_type TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    auto_renew INTEGER NOT NULL DEFAULT 0,
    start_date REAL NOT NULL,
    end_date REAL,
    expiration_date REAL,
    last_validated REAL,
    transaction_id TEXT,
    receipt_data BLOB,
    created_at REAL,
    updated_at REAL
);

-- API usage table
CREATE TABLE IF NOT EXISTS api_usage (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    provider_type TEXT,
    operation_type TEXT,
    date REAL NOT NULL,
    month TEXT NOT NULL,
    requests INTEGER NOT NULL DEFAULT 0,
    tokens INTEGER NOT NULL DEFAULT 0,
    tokens_used INTEGER NOT NULL DEFAULT 0,
    audio_minutes REAL NOT NULL DEFAULT 0.0,
    estimated_cost REAL NOT NULL DEFAULT 0.0,
    response_time REAL NOT NULL DEFAULT 0.0,
    used_at REAL,
    request_metadata BLOB,
    response_metadata BLOB
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_recordings_project_id ON recordings(project_id);
CREATE INDEX IF NOT EXISTS idx_recording_segments_recording_id ON recording_segments(recording_id);
CREATE INDEX IF NOT EXISTS idx_project_tags_project_id ON project_tags(project_id);
CREATE INDEX IF NOT EXISTS idx_project_tags_tag_id ON project_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_api_usage_date ON api_usage(date);
CREATE INDEX IF NOT EXISTS idx_api_usage_month ON api_usage(month);