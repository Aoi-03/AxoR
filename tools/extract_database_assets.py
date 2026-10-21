#!/usr/bin/env python3
"""
AxoR Database Asset Extractor & Populator
1. Copies all audio files into 'AxoR DataBase/Liked_music/'
2. Extracts embedded album art (logos) into 'AxoR DataBase/Liked_music_logo/'
3. Extracts embedded lyrics or fetches synced .lrc lyrics from LRCLIB into 'AxoR DataBase/Liked_music_lyrics/'
4. Generates/updates 'index.json' with all mappings
"""

import os
import sys
import shutil
import json
import re
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed

AUDIO_EXTENSIONS = ('.mp3', '.flac', '.m4a', '.wav', '.ogg', '.aac', '.opus')

def parse_song_name(base_name):
    last_dash = base_name.rfind('-')
    if 0 < last_dash < len(base_name) - 1:
        artist = base_name[:last_dash].strip()
        title = base_name[last_dash + 1:].strip()
    else:
        artist = 'Unknown Artist'
        title = base_name.strip()
    return artist, title

def extract_embedded_image(file_path):
    try:
        with open(file_path, 'rb') as f:
            data = f.read(2 * 1024 * 1024)  # Read first 2MB for artwork
            
            # Check JPEG
            j_start = data.find(b'\xff\xd8\xff')
            if j_start != -1:
                j_end = data.rfind(b'\xff\xd9')
                if j_end > j_start:
                    return data[j_start:j_end + 2], '.jpg'
            
            # Check PNG
            p_start = data.find(b'\x89PNG\r\n\x1a\n')
            if p_start != -1:
                p_end = data.find(b'IEND\xaeB`\x82', p_start)
                if p_end != -1:
                    return data[p_start:p_end + 8], '.png'
    except Exception:
        pass
    return None, None

def extract_embedded_lyrics(file_path):
    try:
        with open(file_path, 'rb') as f:
            data = f.read(1024 * 1024)
            # Search for USLT frame
            idx = data.find(b'USLT')
            if idx != -1:
                frame_data = data[idx+10:idx+4096]
                # Filter printable text
                text = ""
                for byte in frame_data:
                    if 32 <= byte <= 126 or byte in (10, 13):
                        text += chr(byte)
                if len(text.strip()) > 20:
                    return text.strip()
    except Exception:
        pass
    return None

def fetch_lrclib_lyrics(artist, title):
    # Clean artist and title for search query
    clean_artist = artist.replace(';', ' ').split(',')[0].strip()
    clean_title = re.sub(r'\(.*?\)', '', title).strip()
    if not clean_title:
        clean_title = title

    params = {
        'artist_name': clean_artist,
        'track_name': clean_title
    }
    url = f"https://lrclib.net/api/get?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={'User-Agent': 'AxorMusicApp/1.0'})
    try:
        with urllib.request.urlopen(req, timeout=4) as response:
            if response.status == 200:
                res_data = json.loads(response.read().decode('utf-8'))
                synced = res_data.get('syncedLyrics')
                plain = res_data.get('plainLyrics')
                return synced or plain
    except Exception:
        pass
    return None

def process_single_song(f, src_dir, target_music_dir, logo_dir, lyrics_dir):
    src_path = os.path.join(src_dir, f)
    dst_path = os.path.join(target_music_dir, f)
    base, ext = os.path.splitext(f)
    song_id = base.strip()
    artist, title = parse_song_name(song_id)

    # 1. Copy audio file if not already present with same size
    src_size = os.path.getsize(src_path)
    if not os.path.exists(dst_path) or os.path.getsize(dst_path) != src_size:
        shutil.copy2(src_path, dst_path)

    # 2. Extract or check logo
    logo_filename = None
    existing_jpg = os.path.join(logo_dir, f"{song_id}.jpg")
    existing_png = os.path.join(logo_dir, f"{song_id}.png")

    if os.path.exists(existing_jpg):
        logo_filename = f"{song_id}.jpg"
    elif os.path.exists(existing_png):
        logo_filename = f"{song_id}.png"
    else:
        img_bytes, img_ext = extract_embedded_image(src_path)
        if img_bytes and img_ext:
            logo_filename = f"{song_id}{img_ext}"
            out_logo_path = os.path.join(logo_dir, logo_filename)
            with open(out_logo_path, 'wb') as img_out:
                img_out.write(img_bytes)

    # 3. Extract or fetch lyrics
    lyrics_filename = None
    existing_lrc = os.path.join(lyrics_dir, f"{song_id}.lrc")
    existing_txt = os.path.join(lyrics_dir, f"{song_id}.txt")

    if os.path.exists(existing_lrc):
        lyrics_filename = f"{song_id}.lrc"
    elif os.path.exists(existing_txt):
        lyrics_filename = f"{song_id}.txt"
    else:
        # Check embedded lyrics first
        embedded_lyrics = extract_embedded_lyrics(src_path)
        if embedded_lyrics:
            lyrics_filename = f"{song_id}.lrc"
            with open(os.path.join(lyrics_dir, lyrics_filename), 'w', encoding='utf-8') as lrc_out:
                lrc_out.write(embedded_lyrics)
        else:
            # Query LRCLIB for synced/plain lyrics
            online_lyrics = fetch_lrclib_lyrics(artist, title)
            if online_lyrics:
                lyrics_filename = f"{song_id}.lrc"
                with open(os.path.join(lyrics_dir, lyrics_filename), 'w', encoding='utf-8') as lrc_out:
                    lrc_out.write(online_lyrics)

    return {
        "id": song_id,
        "name": f,
        "title": title,
        "artist": artist,
        "fileSize": src_size,
        "format": ext.replace('.', '').upper(),
        "logoFile": logo_filename,
        "lyricsFile": lyrics_filename,
    }

def main():
    default_music = os.environ.get('MUSIC_LIBRARY_PATH', os.path.expanduser('~/Music'))
    src_dir = sys.argv[1] if len(sys.argv) > 1 else default_music
    default_db = os.environ.get('AXOR_DB_PATH', os.path.join(os.path.dirname(src_dir) if src_dir else '.', 'AxoR DataBase'))
    db_root = sys.argv[2] if len(sys.argv) > 2 else default_db

    music_dir = os.path.join(db_root, 'Liked_music')
    logo_dir = os.path.join(db_root, 'Liked_music_logo')
    lyrics_dir = os.path.join(db_root, 'Liked_music_lyrics')

    os.makedirs(music_dir, exist_ok=True)
    os.makedirs(logo_dir, exist_ok=True)
    os.makedirs(lyrics_dir, exist_ok=True)

    files = [f for f in sorted(os.listdir(src_dir)) if f.lower().endswith(AUDIO_EXTENSIONS)]
    total = len(files)
    print(f"🎵 Starting processing of {total} songs...")
    print(f"📁 Source: {src_dir}")
    print(f"📁 Target Database: {db_root}")

    songs_index = []
    completed = 0
    logos_count = 0
    lyrics_count = 0

    # Process in parallel using 8 worker threads for fast I/O and lyrics requests
    with ThreadPoolExecutor(max_workers=8) as executor:
        future_to_song = {
            executor.submit(process_single_song, f, src_dir, music_dir, logo_dir, lyrics_dir): f
            for f in files
        }

        for future in as_completed(future_to_song):
            f_name = future_to_song[future]
            try:
                result = future.result()
                songs_index.append(result)
                completed += 1
                if result.get("logoFile"):
                    logos_count += 1
                if result.get("lyricsFile"):
                    lyrics_count += 1

                if completed % 25 == 0 or completed == total:
                    print(f"⏳ Processed {completed}/{total} songs (Logos: {logos_count}, Lyrics: {lyrics_count})")
            except Exception as e:
                print(f"❌ Error processing {f_name}: {e}")

    # Sort index by song name
    songs_index.sort(key=lambda s: s["name"].lower())

    # Save master index.json
    index_path = os.path.join(db_root, 'index.json')
    with open(index_path, 'w', encoding='utf-8') as out:
        json.dump(songs_index, out, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("✨ ALL SONGS & ASSETS READY IN AxoR DataBase!")
    print(f"✅ Total Songs in Liked_music:   {len(songs_index)}")
    print(f"✅ Extracted Logos in Logo:      {logos_count}")
    print(f"✅ Synced Lyrics in Lyrics:      {lyrics_count}")
    print(f"✅ Master index.json saved to:   {index_path}")
    print("=" * 50)

if __name__ == '__main__':
    main()
