#!/usr/bin/env python3
"""
AxoR Database Synchronizer & Indexer
Creates and synchronizes the AxoR DataBase structure:
  AxoR DataBase/
  ├── index.json
  ├── Liked_music/
  ├── Liked_music_logo/
  └── Liked_music_lyrics/

Rule:
- Song ID = exact downloaded base name (preserves full original track name for CSV compatibility)
- Title/Artist = split on the LAST '-' appeared in the file name:
    - Before last '-' = Artist(s)
    - After last '-' = Song Title (displayed prominently / first in app)
"""

import os
import sys
import json
import re

AUDIO_EXTENSIONS = ('.mp3', '.flac', '.m4a', '.wav', '.ogg', '.aac', '.opus')
IMAGE_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.webp')
LYRICS_EXTENSIONS = ('.lrc', '.txt')

def parse_song_name(base_name):
    last_dash = base_name.rfind('-')
    if 0 < last_dash < len(base_name) - 1:
        artist = base_name[:last_dash].strip()
        title = base_name[last_dash + 1:].strip()
    else:
        artist = 'Unknown Artist'
        title = base_name.strip()
    return artist, title

def build_index(music_dir, output_dir=None):
    if not os.path.exists(music_dir):
        print(f"❌ Music directory not found: {music_dir}")
        return []

    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(music_dir), 'AxoR DataBase')

    music_sub = os.path.join(output_dir, 'Liked_music')
    logo_sub = os.path.join(output_dir, 'Liked_music_logo')
    lyrics_sub = os.path.join(output_dir, 'Liked_music_lyrics')

    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(music_sub, exist_ok=True)
    os.makedirs(logo_sub, exist_ok=True)
    os.makedirs(lyrics_sub, exist_ok=True)

    # 1. Index available logos
    logo_map = {}
    if os.path.exists(logo_sub):
        for img in os.listdir(logo_sub):
            base, ext = os.path.splitext(img)
            if ext.lower() in IMAGE_EXTENSIONS:
                logo_map[base.lower().strip()] = img
                _, t = parse_song_name(base)
                logo_map[t.lower().strip()] = img

    # 2. Index available lyrics
    lyrics_map = {}
    if os.path.exists(lyrics_sub):
        for lrc in os.listdir(lyrics_sub):
            base, ext = os.path.splitext(lrc)
            if ext.lower() in LYRICS_EXTENSIONS:
                lyrics_map[base.lower().strip()] = lrc
                _, t = parse_song_name(base)
                lyrics_map[t.lower().strip()] = lrc

    # 3. Scan all audio files
    songs = []
    files = sorted(os.listdir(music_dir))
    for f in files:
        base, ext = os.path.splitext(f)
        if ext.lower() not in AUDIO_EXTENSIONS:
            continue

        file_path = os.path.join(music_dir, f)
        file_size = os.path.getsize(file_path)
        base_name = base.strip()
        song_id = base_name  # EXACT downloaded name as ID

        artist, title = parse_song_name(base_name)

        matched_logo = logo_map.get(base_name.lower()) or logo_map.get(title.lower())
        matched_lyrics = lyrics_map.get(base_name.lower()) or lyrics_map.get(title.lower())

        song_entry = {
            "id": song_id,
            "name": f,
            "title": title,
            "artist": artist,
            "fileSize": file_size,
            "format": ext.replace('.', '').upper(),
            "logoFile": matched_logo,
            "lyricsFile": matched_lyrics,
        }
        songs.append(song_entry)

    # 4. Write index.json
    index_path = os.path.join(output_dir, 'index.json')
    with open(index_path, 'w', encoding='utf-8') as out:
        json.dump(songs, out, indent=2, ensure_ascii=False)

    print(f"✅ Generated index.json with {len(songs)} songs at: {index_path}")
    print(f"📁 Database structure ready at: {output_dir}")
    return songs

if __name__ == '__main__':
    default_source = os.environ.get('MUSIC_LIBRARY_PATH', os.path.expanduser('~/Music'))
    source = sys.argv[1] if len(sys.argv) > 1 else default_source
    build_index(source)

