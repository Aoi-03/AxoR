const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const mm = require('music-metadata');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Storage mode: 'local' or 'mega'
const STORAGE_MODE = process.env.STORAGE_MODE || 'local';

// Music library path - YOUR ACTUAL MUSIC FOLDER (for local mode)
const MUSIC_LIBRARY_PATH = process.env.MUSIC_LIBRARY_PATH || 'C:\\Users\\LUNA\\Downloads\\AI';

// MEGA configuration (for mega mode)
const MEGA_PUBLIC_FOLDER_URL = process.env.MEGA_PUBLIC_FOLDER_URL || 'https://mega.nz/folder/X3BR2aZR#09OOI5s-5vtw0BBomoHphw';

// MEGA service instance
let megaService = null;
if (STORAGE_MODE === 'mega') {
  const MegaPublicService = require('./mega_public_service');
  megaService = new MegaPublicService(MEGA_PUBLIC_FOLDER_URL);
}

// Serve static files (songs from your library) - only for local mode
if (STORAGE_MODE === 'local') {
  app.use('/songs', express.static(MUSIC_LIBRARY_PATH));
}

// Database paths (only for users and playlists)
const DB_PATH = path.join(__dirname, '../database');
const USERS_DB = path.join(DB_PATH, 'users.json');
const PLAYLISTS_DB = path.join(DB_PATH, 'playlists.json');

// Metadata cache path
const METADATA_CACHE_DIR = path.join(__dirname, 'song_metadata_cache');
const METADATA_CACHE_FILE = path.join(METADATA_CACHE_DIR, 'song_metadata.json');

// MEGA file cache path
const MEGA_CACHE_DIR = path.join(__dirname, 'mega_cache');
const MEGA_CACHE_COVERS_DIR = path.join(MEGA_CACHE_DIR, 'covers');
const MEGA_CACHE_FILES_DIR = path.join(MEGA_CACHE_DIR, 'files');

// Cache configuration
const MAX_CACHED_SONGS = 3; // Keep max 3 songs in cache (safe for server)
const PRIORITY_CACHE_COUNT = 3; // Pre-cache first 3 songs

// In-memory songs cache (scanned from your FLAC files or MEGA)
let songsCache = [];
let metadataCache = {};
let megaFileCache = new Map(); // Cache for downloaded MEGA files: songId -> { path, lastUsed, size }
let cacheQueue = []; // Track cache order for LRU
let cachingInProgress = new Map(); // Track songs currently being cached: songId -> { progress, startTime }

// Helper: Read JSON file
const readJSON = (filePath) => {
  try {
    if (!fs.existsSync(filePath)) {
      return filePath.includes('users') ? [] : 
             filePath.includes('playlists') ? [] : {};
    }
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    console.error(`Error reading ${filePath}:`, error);
    return [];
  }
};

// Helper: Write JSON file
const writeJSON = (filePath, data) => {
  try {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    console.error(`Error writing ${filePath}:`, error);
    return false;
  }
};

// Helper: Load metadata cache
function loadMetadataCache() {
  try {
    if (!fs.existsSync(METADATA_CACHE_DIR)) {
      fs.mkdirSync(METADATA_CACHE_DIR, { recursive: true });
    }
    
    if (fs.existsSync(METADATA_CACHE_FILE)) {
      const data = fs.readFileSync(METADATA_CACHE_FILE, 'utf8');
      metadataCache = JSON.parse(data);
      console.log(`📦 Loaded ${Object.keys(metadataCache).length} cached song metadata`);
    } else {
      metadataCache = {};
      console.log('📦 No metadata cache found, starting fresh');
    }
  } catch (error) {
    console.error('❌ Error loading metadata cache:', error);
    metadataCache = {};
  }
}

// Helper: Initialize MEGA cache directories
function initMegaCache() {
  try {
    if (!fs.existsSync(MEGA_CACHE_DIR)) {
      fs.mkdirSync(MEGA_CACHE_DIR, { recursive: true });
    }
    if (!fs.existsSync(MEGA_CACHE_COVERS_DIR)) {
      fs.mkdirSync(MEGA_CACHE_COVERS_DIR, { recursive: true });
    }
    if (!fs.existsSync(MEGA_CACHE_FILES_DIR)) {
      fs.mkdirSync(MEGA_CACHE_FILES_DIR, { recursive: true });
    }
    
    // Load existing cache
    const cachedFiles = fs.readdirSync(MEGA_CACHE_FILES_DIR);
    for (const file of cachedFiles) {
      if (file.endsWith('.flac')) {
        const songId = file.replace('.flac', '');
        const filePath = path.join(MEGA_CACHE_FILES_DIR, file);
        const stats = fs.statSync(filePath);
        megaFileCache.set(songId, {
          path: filePath,
          lastUsed: stats.mtime,
          size: stats.size
        });
        cacheQueue.push(songId);
      }
    }
    
    console.log(`📁 MEGA cache initialized (${megaFileCache.size} songs cached)`);
    
    // Clean up if over limit
    while (megaFileCache.size > MAX_CACHED_SONGS) {
      console.log(`🧹 Cleaning up cache (${megaFileCache.size}/${MAX_CACHED_SONGS})...`);
      removeOldestCache();
    }
    
    console.log(`✅ Cache ready (${megaFileCache.size}/${MAX_CACHED_SONGS} slots used)`);
  } catch (error) {
    console.error('❌ Error initializing MEGA cache:', error);
  }
}

// Helper: Remove oldest cached file (LRU)
function removeOldestCache() {
  if (cacheQueue.length === 0) return;
  
  const oldestSongId = cacheQueue.shift();
  const cacheInfo = megaFileCache.get(oldestSongId);
  
  if (cacheInfo) {
    try {
      if (fs.existsSync(cacheInfo.path)) {
        fs.unlinkSync(cacheInfo.path);
        console.log(`🗑️  Removed old cache: ${oldestSongId}`);
      }
      megaFileCache.delete(oldestSongId);
    } catch (error) {
      console.error(`❌ Error removing cache:`, error.message);
    }
  }
}

// Helper: Update cache usage (move to end of queue)
function updateCacheUsage(songId) {
  const index = cacheQueue.indexOf(songId);
  if (index > -1) {
    cacheQueue.splice(index, 1);
  }
  cacheQueue.push(songId);
  
  const cacheInfo = megaFileCache.get(songId);
  if (cacheInfo) {
    cacheInfo.lastUsed = new Date();
  }
}

// Helper: Cache MEGA file to disk with LRU management
async function cacheMegaFile(song, priority = false) {
  try {
    const cacheFilePath = path.join(MEGA_CACHE_FILES_DIR, `${song.id}.flac`);
    
    // Check if already cached
    if (megaFileCache.has(song.id)) {
      console.log(`✅ Already cached: ${song.title}`);
      updateCacheUsage(song.id);
      return megaFileCache.get(song.id).path;
    }
    
    // Check if already caching
    if (cachingInProgress.has(song.id)) {
      console.log(`⏳ Already caching: ${song.title}`);
      // Wait for it to finish
      while (cachingInProgress.has(song.id)) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      return megaFileCache.get(song.id)?.path;
    }
    
    // Mark as caching
    cachingInProgress.set(song.id, {
      progress: 0,
      startTime: Date.now(),
      title: song.title
    });
    
    // Check cache limit - remove oldest if full
    if (megaFileCache.size >= MAX_CACHED_SONGS) {
      console.log(`📦 Cache full (${megaFileCache.size}/${MAX_CACHED_SONGS}), removing oldest...`);
      removeOldestCache();
    }
    
    console.log(`${priority ? '⚡' : '📥'} Caching: ${song.title}`);
    const startTime = Date.now();
    
    // Download from MEGA with progress tracking
    const chunks = [];
    let downloadedBytes = 0;
    const megaStream = song.megaFile.download();
    
    megaStream.on('data', (chunk) => {
      chunks.push(chunk);
      downloadedBytes += chunk.length;
      
      // Update progress
      const progress = Math.round((downloadedBytes / song.fileSize) * 100);
      cachingInProgress.set(song.id, {
        progress: progress,
        startTime: startTime,
        title: song.title,
        downloadedBytes: downloadedBytes,
        totalBytes: song.fileSize
      });
    });
    
    await new Promise((resolve, reject) => {
      megaStream.on('end', () => resolve());
      megaStream.on('error', (error) => reject(error));
    });
    
    const fileBuffer = Buffer.concat(chunks);
    const downloadTime = ((Date.now() - startTime) / 1000).toFixed(1);
    
    // Save to disk
    fs.writeFileSync(cacheFilePath, fileBuffer);
    
    megaFileCache.set(song.id, {
      path: cacheFilePath,
      lastUsed: new Date(),
      size: fileBuffer.length
    });
    cacheQueue.push(song.id);
    
    // Remove from caching progress
    cachingInProgress.delete(song.id);
    
    console.log(`✅ Cached: ${song.title} (${(fileBuffer.length / 1024 / 1024).toFixed(1)} MB in ${downloadTime}s)`);
    
    // Also extract and cache cover
    await extractAndCacheCover(song.id, fileBuffer);
    
    return cacheFilePath;
  } catch (error) {
    console.error(`❌ Error caching ${song.title}:`, error.message);
    cachingInProgress.delete(song.id);
    return null;
  }
}

// Helper: Extract and cache cover from file buffer
async function extractAndCacheCover(songId, fileBuffer) {
  try {
    const coverCachePath = path.join(MEGA_CACHE_COVERS_DIR, `${songId}.jpg`);
    
    // Check if already cached
    if (fs.existsSync(coverCachePath)) {
      return coverCachePath;
    }
    
    // Look for JPEG in file
    let imageStart = -1;
    let imageEnd = -1;
    
    for (let i = 0; i < fileBuffer.length - 3; i++) {
      if (fileBuffer[i] === 0xFF && fileBuffer[i + 1] === 0xD8 && fileBuffer[i + 2] === 0xFF) {
        imageStart = i;
        for (let j = i + 3; j < fileBuffer.length - 1; j++) {
          if (fileBuffer[j] === 0xFF && fileBuffer[j + 1] === 0xD9) {
            imageEnd = j + 2;
            break;
          }
        }
        break;
      }
    }
    
    if (imageStart !== -1 && imageEnd !== -1) {
      const imageBuffer = fileBuffer.slice(imageStart, imageEnd);
      fs.writeFileSync(coverCachePath, imageBuffer);
      console.log(`🖼️  Cached cover for song ${songId}`);
      return coverCachePath;
    }
    
    return null;
  } catch (error) {
    console.error(`❌ Error caching cover:`, error.message);
    return null;
  }
}

// Helper: Pre-cache all covers at startup (DISABLED for memory optimization)
async function preCacheAllCovers() {
  // DISABLED: Pre-caching all covers uses too much memory on free tier (512MB limit)
  // Covers will be cached on-demand when requested instead
  console.log(`ℹ️  Cover pre-caching disabled (on-demand caching enabled)`);
  return;
  
  /* ORIGINAL CODE - DISABLED
  if (STORAGE_MODE !== 'mega' || songsCache.length === 0) return;
  
  console.log(`🖼️  Pre-caching covers for ${songsCache.length} songs...`);
  
  let cachedCount = 0;
  let alreadyCached = 0;
  
  for (const song of songsCache) {
    const coverCachePath = path.join(MEGA_CACHE_COVERS_DIR, `${song.id}.jpg`);
    
    // Check if already cached
    if (fs.existsSync(coverCachePath)) {
      alreadyCached++;
      continue;
    }
    
    try {
      // Download file to extract cover
      const chunks = [];
      const megaStream = song.megaFile.download();
      
      await new Promise((resolve, reject) => {
        megaStream.on('data', (chunk) => chunks.push(chunk));
        megaStream.on('end', () => resolve());
        megaStream.on('error', (error) => reject(error));
      });
      
      const fileBuffer = Buffer.concat(chunks);
      
      // Extract and cache cover
      await extractAndCacheCover(song.id, fileBuffer);
      cachedCount++;
      
      console.log(`🖼️  Cached cover ${cachedCount}/${songsCache.length - alreadyCached}: ${song.title}`);
      
    } catch (error) {
      console.error(`❌ Error caching cover for ${song.title}:`, error.message);
    }
  }
  
  console.log(`✅ Cover pre-caching complete! (${alreadyCached} already cached, ${cachedCount} newly cached)`);
  */
}

// Helper: Save metadata cache
function saveMetadataCache() {
  try {
    if (!fs.existsSync(METADATA_CACHE_DIR)) {
      fs.mkdirSync(METADATA_CACHE_DIR, { recursive: true });
    }
    fs.writeFileSync(METADATA_CACHE_FILE, JSON.stringify(metadataCache, null, 2));
    console.log(`💾 Saved ${Object.keys(metadataCache).length} song metadata to cache`);
  } catch (error) {
    console.error('❌ Error saving metadata cache:', error);
  }
}

// Helper: Fetch song metadata from Last.fm (primary) with MusicBrainz fallback
async function fetchSongMetadata(songTitle, artistName) {
  try {
    // Clean up title and artist for search
    const cleanTitle = songTitle.replace(/\(.*?\)/g, '').trim();
    const cleanArtist = artistName.replace(/Unknown Artist/gi, '').trim();
    
    // Try Last.fm first (more accurate for emotions)
    const lastfmData = await fetchFromLastFm(cleanTitle, cleanArtist);
    if (lastfmData) {
      console.log(`✅ Last.fm: ${cleanTitle} - Tags: ${lastfmData.tags.join(', ')}`);
      return lastfmData;
    }
    
    // Fallback to MusicBrainz
    console.log(`⚠️  Last.fm failed, trying MusicBrainz...`);
    const musicbrainzData = await fetchFromMusicBrainz(cleanTitle, cleanArtist);
    if (musicbrainzData) {
      return musicbrainzData;
    }
    
    return null;
  } catch (error) {
    console.log(`⚠️  Could not fetch metadata: ${error.message}`);
    return null;
  }
}

// Helper: Fetch from Last.fm API (primary source)
async function fetchFromLastFm(title, artist) {
  try {
    // Last.fm API endpoint - using public method without API key
    // Note: This uses the public track search which doesn't require authentication
    const url = `http://ws.audioscrobbler.com/2.0/?method=track.search&track=${encodeURIComponent(title)}&artist=${encodeURIComponent(artist)}&format=json&limit=1`;
    
    const response = await axios.get(url, {
      timeout: 5000,
      headers: { 'User-Agent': 'AxorMusicApp/1.0' }
    });
    
    if (response.data && response.data.results && response.data.results.trackmatches) {
      const tracks = response.data.results.trackmatches.track;
      if (!tracks || tracks.length === 0) {
        return null;
      }
      
      const track = Array.isArray(tracks) ? tracks[0] : tracks;
      
      // Extract basic info from search result
      // Note: Free API doesn't give us tags directly, so we'll use genre estimation
      const trackName = track.name || title;
      const trackArtist = track.artist || artist;
      
      // Estimate from track name and artist
      const { mood, energy, emotions } = estimateFromTrackInfo(trackName, trackArtist);
      
      return {
        genres: ['Unknown'],
        mood: mood,
        energy: energy,
        emotions: emotions,
        tags: [mood],
        tempo: 120,
        source: 'lastfm-search',
        fetchedAt: new Date().toISOString()
      };
    }
    
    return null;
  } catch (error) {
    console.log(`⚠️  Last.fm error: ${error.message}`);
    return null;
  }
}

// Helper: Estimate emotions from track name and artist (enhanced heuristics)
function estimateFromTrackInfo(title, artist) {
  const combined = `${title} ${artist}`.toLowerCase();
  
  // High energy keywords
  if (combined.match(/beast|power|thunder|rage|fire|battle|war|fight|attack|rumbling|specialz|gym|workout|intense|aggressive|metal|rock|edm|electronic|dubstep/)) {
    return { mood: 'energetic', energy: 0.85, emotions: ['energetic', 'powerful'] };
  }
  
  // Sad keywords
  if (combined.match(/sad|cry|tear|broken|hurt|pain|alone|lost|goodbye|farewell|miss|sorry|regret|melanchol|depress/)) {
    return { mood: 'sad', energy: 0.3, emotions: ['sad', 'melancholic'] };
  }
  
  // Happy keywords
  if (combined.match(/happy|joy|smile|love|beautiful|wonderful|amazing|celebrate|party|dance|upbeat|cheerful/)) {
    return { mood: 'happy', energy: 0.7, emotions: ['happy', 'joyful'] };
  }
  
  // Calm keywords
  if (combined.match(/calm|peace|relax|chill|ambient|sleep|dream|soft|gentle|quiet|study|focus|meditation/)) {
    return { mood: 'calm', energy: 0.4, emotions: ['calm', 'peaceful'] };
  }
  
  // Anime/Epic keywords
  if (combined.match(/odyssey|epic|hero|legend|destiny|fate|opening|theme|ost|soundtrack|anime|naruto|dragon ball|attack on titan/)) {
    return { mood: 'energetic', energy: 0.75, emotions: ['epic', 'energetic'] };
  }
  
  // Default neutral
  return { mood: 'neutral', energy: 0.6, emotions: ['neutral'] };
}

// Helper: Fetch from MusicBrainz (fallback)
async function fetchFromMusicBrainz(title, artist) {
  try {
    const searchQuery = artist ? `${title} ${artist}` : title;
    const url = `https://musicbrainz.org/ws/2/recording/?query=${encodeURIComponent(searchQuery)}&fmt=json&limit=1`;
    
    const response = await axios.get(url, {
      headers: { 'User-Agent': 'AxorMusicApp/1.0' },
      timeout: 5000
    });
    
    if (response.data.recordings && response.data.recordings.length > 0) {
      const recording = response.data.recordings[0];
      
      // Extract tags (genres)
      const tags = recording.tags || [];
      const genres = tags.map(t => t.name).slice(0, 3);
      
      // Estimate mood and energy from genres
      const { mood, energy } = estimateMoodFromGenres(genres);
      
      return {
        genres: genres.length > 0 ? genres : ['Unknown'],
        mood: mood,
        energy: energy,
        emotions: [mood], // Single emotion from genre estimation
        tags: genres,
        tempo: recording.length ? Math.round(120 + (recording.length % 60)) : 120,
        source: 'musicbrainz',
        fetchedAt: new Date().toISOString()
      };
    }
    
    return null;
  } catch (error) {
    console.log(`⚠️  MusicBrainz error: ${error.message}`);
    return null;
  }
}

// Helper: Map Last.fm tags to emotions and energy levels
function mapTagsToEmotions(tags) {
  const emotions = [];
  let totalEnergy = 0;
  let energyCount = 0;
  let primaryMood = 'neutral';
  
  // Emotion mapping with energy values
  const emotionMap = {
    // High energy emotions
    'energetic': { mood: 'energetic', energy: 0.9, emotions: ['energetic', 'powerful'] },
    'upbeat': { mood: 'energetic', energy: 0.85, emotions: ['happy', 'energetic'] },
    'powerful': { mood: 'energetic', energy: 0.9, emotions: ['powerful', 'intense'] },
    'intense': { mood: 'energetic', energy: 0.85, emotions: ['intense', 'passionate'] },
    'aggressive': { mood: 'angry', energy: 0.9, emotions: ['angry', 'aggressive'] },
    'angry': { mood: 'angry', energy: 0.85, emotions: ['angry', 'intense'] },
    
    // Happy emotions
    'happy': { mood: 'happy', energy: 0.7, emotions: ['happy', 'joyful'] },
    'uplifting': { mood: 'happy', energy: 0.75, emotions: ['uplifting', 'hopeful'] },
    'cheerful': { mood: 'happy', energy: 0.7, emotions: ['cheerful', 'bright'] },
    'joyful': { mood: 'happy', energy: 0.75, emotions: ['joyful', 'happy'] },
    
    // Sad emotions
    'sad': { mood: 'sad', energy: 0.3, emotions: ['sad', 'melancholic'] },
    'melancholic': { mood: 'sad', energy: 0.35, emotions: ['melancholic', 'nostalgic'] },
    'depressing': { mood: 'sad', energy: 0.25, emotions: ['sad', 'dark'] },
    'emotional': { mood: 'sad', energy: 0.4, emotions: ['emotional', 'touching'] },
    'dark': { mood: 'sad', energy: 0.35, emotions: ['dark', 'somber'] },
    
    // Calm emotions
    'chill': { mood: 'calm', energy: 0.4, emotions: ['calm', 'relaxed'] },
    'calm': { mood: 'calm', energy: 0.35, emotions: ['calm', 'peaceful'] },
    'peaceful': { mood: 'calm', energy: 0.3, emotions: ['peaceful', 'serene'] },
    'relaxing': { mood: 'calm', energy: 0.35, emotions: ['relaxing', 'soothing'] },
    'ambient': { mood: 'calm', energy: 0.3, emotions: ['ambient', 'atmospheric'] },
    'mellow': { mood: 'calm', energy: 0.4, emotions: ['mellow', 'smooth'] },
    
    // Neutral/other
    'atmospheric': { mood: 'neutral', energy: 0.5, emotions: ['atmospheric', 'ambient'] },
    'epic': { mood: 'energetic', energy: 0.8, emotions: ['epic', 'grand'] },
    'beautiful': { mood: 'happy', energy: 0.6, emotions: ['beautiful', 'lovely'] },
  };
  
  // Process each tag
  for (const tag of tags) {
    const mapping = emotionMap[tag];
    if (mapping) {
      emotions.push(...mapping.emotions);
      totalEnergy += mapping.energy;
      energyCount++;
      
      // Set primary mood from first matched tag
      if (primaryMood === 'neutral') {
        primaryMood = mapping.mood;
      }
    }
  }
  
  // Calculate average energy
  const avgEnergy = energyCount > 0 ? totalEnergy / energyCount : 0.6;
  
  // Remove duplicates from emotions
  const uniqueEmotions = [...new Set(emotions)];
  
  return {
    mood: primaryMood,
    energy: avgEnergy,
    emotions: uniqueEmotions.length > 0 ? uniqueEmotions : ['neutral']
  };
}

// Helper: Estimate mood and energy from genres
function estimateMoodFromGenres(genres) {
  const genreStr = genres.join(' ').toLowerCase();
  
  let energy = 0.6; // Default
  let mood = 'neutral';
  
  // High energy genres
  if (genreStr.match(/rock|metal|punk|hardcore|edm|electronic|dance|techno|dubstep|drum and bass/)) {
    energy = 0.85;
    mood = 'energetic';
  }
  // Medium-high energy
  else if (genreStr.match(/pop|hip hop|rap|r&b|funk|disco/)) {
    energy = 0.7;
    mood = 'upbeat';
  }
  // Medium energy
  else if (genreStr.match(/indie|alternative|folk|country/)) {
    energy = 0.55;
    mood = 'neutral';
  }
  // Low energy
  else if (genreStr.match(/ambient|classical|jazz|blues|acoustic|ballad/)) {
    energy = 0.35;
    mood = 'calm';
  }
  // Sad/emotional
  else if (genreStr.match(/sad|melancholic|emotional/)) {
    energy = 0.4;
    mood = 'sad';
  }
  
  return { mood, energy };
}

// Helper: Scan FLAC files and extract metadata
async function scanMusicLibrary() {
  console.log('🔍 Scanning music library:', MUSIC_LIBRARY_PATH);
  
  if (!fs.existsSync(MUSIC_LIBRARY_PATH)) {
    console.error('❌ Music library path does not exist:', MUSIC_LIBRARY_PATH);
    return [];
  }
  
  const songs = [];
  const files = fs.readdirSync(MUSIC_LIBRARY_PATH);
  let successCount = 0;
  let errorCount = 0;
  
  for (const file of files) {
    if (file.endsWith('.flac')) {
      try {
        const filePath = path.join(MUSIC_LIBRARY_PATH, file);
        const fileStats = fs.statSync(filePath);
        
        // Try to parse metadata, but continue even if it fails
        let metadata = null;
        try {
          metadata = await mm.parseFile(filePath, { duration: true, skipCovers: false });
        } catch (metaError) {
          console.log(`⚠️  Could not read metadata for ${file}, using filename`);
        }
        
        // Extract metadata from FLAC (or use filename if metadata fails)
        const common = metadata ? metadata.common : {};
        const format = metadata ? metadata.format : {};
        
        // Generate song ID from filename
        const songId = `song_${file.replace('.flac', '').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50)}`;
        
        // Use filename as title if no metadata
        const title = common.title || file.replace('.flac', '');
        const artist = common.artist || 'Unknown Artist';
        
        // Estimate BPM and energy
        const bpm = estimateBPM(title);
        const energy = estimateEnergy(common.genre ? common.genre[0] : '');
        const mood = estimateMood(energy);
        
        const song = {
          id: songId,
          title: title,
          artist: artist,
          album: common.album || 'Unknown Album',
          duration: Math.round(format.duration || 0),
          bpm: bpm,
          energy: energy,
          mood: mood,
          genre: common.genre ? common.genre[0] : 'Unknown',
          filePath: `/songs/${encodeURIComponent(file)}`,
          coverPath: 'embedded', // Assume all FLAC files have embedded covers
          fileSize: fileStats.size,
          format: 'FLAC',
          sampleRate: format.sampleRate || 44100,
          bitrate: format.bitrate || 1411,
          year: common.year || null,
          fileName: file
        };
        
        songs.push(song);
        successCount++;
        if (successCount <= 10) {
          console.log(`✅ ${successCount}. ${song.title} - ${song.artist}`);
        }
      } catch (error) {
        errorCount++;
        if (errorCount <= 5) {
          console.error(`❌ Error processing ${file}:`, error.message);
        }
      }
    }
  }
  
  console.log(`\n🎵 Scan complete!`);
  console.log(`✅ Successfully scanned: ${successCount} songs`);
  if (errorCount > 0) {
    console.log(`⚠️  Errors: ${errorCount} files`);
  }
  
  return songs;
}

// Helper: Estimate BPM (simple heuristic, can be improved)
function estimateBPM(title) {
  const lower = title.toLowerCase();
  if (lower.includes('gym') || lower.includes('workout') || lower.includes('beast')) return 150;
  if (lower.includes('study') || lower.includes('focus') || lower.includes('calm')) return 80;
  if (lower.includes('drive') || lower.includes('road')) return 110;
  if (lower.includes('thunder') || lower.includes('power')) return 140;
  return 120; // Default
}

// Helper: Estimate energy (simple heuristic, can be improved)
function estimateEnergy(genre) {
  const lower = genre.toLowerCase();
  if (lower.includes('edm') || lower.includes('electronic') || lower.includes('hardcore')) return 0.9;
  if (lower.includes('rock') || lower.includes('metal')) return 0.8;
  if (lower.includes('pop')) return 0.7;
  if (lower.includes('ambient') || lower.includes('classical')) return 0.3;
  if (lower.includes('jazz') || lower.includes('blues')) return 0.5;
  return 0.6; // Default
}

// Helper: Estimate mood from energy
function estimateMood(energy) {
  if (energy >= 0.8) return 'energetic';
  if (energy >= 0.6) return 'neutral';
  if (energy >= 0.4) return 'calm';
  return 'sad';
}

// Helper: Remove megaFile from song (to avoid circular reference in JSON)
function cleanSong(song) {
  const { megaFile, ...songWithoutMegaFile } = song;
  return songWithoutMegaFile;
}

// Helper: Remove megaFile from array of songs
function cleanSongs(songs) {
  return songs.map(cleanSong);
}

// Initialize: Load metadata cache and scan library on startup
(async () => {
  console.log('========================================');
  console.log('  AXOR Music Backend');
  console.log('========================================');
  console.log(`📦 Storage Mode: ${STORAGE_MODE.toUpperCase()}`);
  console.log('');
  
  loadMetadataCache();
  initMegaCache();
  
  if (STORAGE_MODE === 'mega') {
    // MEGA mode - using public folder
    console.log('🌐 Using MEGA Cloud Storage (Public Folder)');
    const connected = await megaService.loadFolder();
    if (connected) {
      const megaSongs = await megaService.listFiles();
      
      // Convert MEGA songs to our format
      songsCache = megaSongs.map((megaSong) => {
        const songId = megaSong.id;
        const title = megaSong.name.replace('.flac', '');
        
        return {
          id: songId,
          title: title,
          artist: 'Unknown Artist',
          album: 'Unknown Album',
          duration: 0,
          bpm: 120,
          energy: 0.6,
          mood: 'neutral',
          genre: 'Unknown',
          filePath: `/api/songs/stream/${songId}`, // Use backend streaming endpoint
          coverPath: 'embedded',
          fileSize: megaSong.size,
          format: 'FLAC',
          sampleRate: 44100,
          bitrate: 1411,
          year: null,
          fileName: megaSong.name,
          megaFile: megaSong.megaFile // Store MEGA file object for streaming
        };
      });
      
      console.log(`✅ Loaded ${songsCache.length} songs from MEGA public folder`);
      
      // Pre-cache all covers in background
      console.log('🖼️  Starting cover pre-caching in background...');
      preCacheAllCovers().then(() => {
        console.log('✅ All covers ready!');
      }).catch(error => {
        console.error('❌ Cover pre-caching error:', error.message);
      });
    } else {
      console.error('❌ Failed to load MEGA public folder. Check the URL in .env');
    }
  } else {
    // Local mode
    console.log('💻 Using Local File Storage');
    console.log(`📁 Path: ${MUSIC_LIBRARY_PATH}`);
    songsCache = await scanMusicLibrary();
  }
})();

// ==================== AUTH ROUTES ====================

// Login
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;
  const users = readJSON(USERS_DB);
  
  const user = users.find(u => u.email === email && u.password === password);
  
  if (user) {
    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        plan: user.plan,
        storageUsed: user.storageUsed,
        storageLimit: user.storageLimit
      }
    });
  } else {
    res.status(401).json({ success: false, message: 'Invalid credentials' });
  }
});

// Signup
app.post('/api/auth/signup', (req, res) => {
  const { email, password, username } = req.body;
  const users = readJSON(USERS_DB);
  
  if (users.find(u => u.email === email)) {
    return res.status(400).json({ success: false, message: 'Email already exists' });
  }
  
  const newUser = {
    id: `user_${Date.now()}`,
    email,
    password,
    username: username || email.split('@')[0],
    plan: 'free',
    storageUsed: 0,
    storageLimit: 1, // 1GB for free users
    likedSongs: [],
    playlists: [],
    createdAt: new Date().toISOString()
  };
  
  users.push(newUser);
  writeJSON(USERS_DB, users);
  
  res.json({
    success: true,
    user: {
      id: newUser.id,
      email: newUser.email,
      username: newUser.username,
      plan: newUser.plan
    }
  });
});

// ==================== SONGS ROUTES ====================

// Get all songs (from scanned library)
app.get('/api/songs', (req, res) => {
  console.log(`📋 Songs list requested - returning ${songsCache.length} songs`);
  
  // Log first song's filePath for debugging
  if (songsCache.length > 0) {
    console.log(`🔍 Sample song filePath: ${songsCache[0].filePath}`);
  }
  
  // Remove megaFile object to avoid circular reference
  const songsToSend = songsCache.map(song => {
    const { megaFile, ...songWithoutMegaFile } = song;
    return songWithoutMegaFile;
  });
  
  res.json({ success: true, songs: songsToSend });
});

// Rescan library
app.post('/api/songs/rescan', async (req, res) => {
  console.log('🔄 Rescanning music library...');
  songsCache = await scanMusicLibrary();
  res.json({ success: true, count: songsCache.length });
});

// Search songs
app.post('/api/songs/search', (req, res) => {
  const { query } = req.body;
  
  const results = songsCache.filter(song => 
    song.title.toLowerCase().includes(query.toLowerCase()) ||
    song.artist.toLowerCase().includes(query.toLowerCase()) ||
    song.album.toLowerCase().includes(query.toLowerCase())
  );
  
  res.json({ success: true, results });
});

// Like/Unlike song
app.post('/api/songs/like/:songId', (req, res) => {
  const { songId } = req.params;
  const { userId } = req.body;
  
  const users = readJSON(USERS_DB);
  const user = users.find(u => u.id === userId);
  
  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }
  
  const isLiked = user.likedSongs.includes(songId);
  
  if (isLiked) {
    user.likedSongs = user.likedSongs.filter(id => id !== songId);
  } else {
    user.likedSongs.push(songId);
  }
  
  writeJSON(USERS_DB, users);
  
  res.json({ success: true, isLiked: !isLiked });
});

// Get user's liked songs
app.get('/api/songs/liked/:userId', (req, res) => {
  const { userId } = req.params;
  const users = readJSON(USERS_DB);
  
  const user = users.find(u => u.id === userId);
  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }
  
  const likedSongs = songsCache.filter(song => user.likedSongs.includes(song.id));
  
  res.json({ success: true, songs: likedSongs });
});

// Get album art from FLAC file - Works for both LOCAL and MEGA modes
app.get('/api/songs/cover/:songId', async (req, res) => {
  const { songId } = req.params;
  
  try {
    const song = songsCache.find(s => s.id === songId);
    if (!song) {
      console.log(`❌ Cover not found for songId: ${songId}`);
      return res.status(404).json({ success: false, message: 'Song not found' });
    }
    
    // Check if cover is cached
    const coverCachePath = path.join(MEGA_CACHE_COVERS_DIR, `${songId}.jpg`);
    if (fs.existsSync(coverCachePath)) {
      const imageBuffer = fs.readFileSync(coverCachePath);
      res.set('Content-Type', 'image/jpeg');
      res.set('Cache-Control', 'public, max-age=86400');
      res.send(imageBuffer);
      console.log(`✅ Served cached cover for: ${song.title}`);
      return;
    }
    
    let fileBuffer;
    
    if (STORAGE_MODE === 'mega') {
      // Check if file is cached
      const cacheInfo = megaFileCache.get(songId);
      if (cacheInfo && fs.existsSync(cacheInfo.path)) {
        fileBuffer = fs.readFileSync(cacheInfo.path);
        console.log(`✅ Using cached file for cover: ${song.title}`);
      } else {
        // Download from MEGA
        console.log(`📥 Downloading from MEGA to extract cover: ${song.title}`);
        
        if (!song.megaFile) {
          return res.status(404).json({ success: false, message: 'MEGA file not found' });
        }
        
        const chunks = [];
        const megaStream = song.megaFile.download();
        
        await new Promise((resolve, reject) => {
          megaStream.on('data', (chunk) => chunks.push(chunk));
          megaStream.on('end', () => resolve());
          megaStream.on('error', (error) => reject(error));
        });
        
        fileBuffer = Buffer.concat(chunks);
        console.log(`✅ Downloaded ${fileBuffer.length} bytes from MEGA`);
      }
      
    } else {
      // LOCAL mode - read from file system
      if (!song.fileName) {
        return res.status(404).json({ success: false, message: 'File name not found' });
      }
      
      const filePath = path.join(MUSIC_LIBRARY_PATH, song.fileName);
      
      if (!fs.existsSync(filePath)) {
        console.log(`❌ File does not exist: ${filePath}`);
        return res.status(404).json({ success: false, message: 'File not found' });
      }
      
      fileBuffer = fs.readFileSync(filePath);
    }
    
    // Extract cover and cache it
    const cachedCover = await extractAndCacheCover(songId, fileBuffer);
    
    if (cachedCover && fs.existsSync(cachedCover)) {
      const imageBuffer = fs.readFileSync(cachedCover);
      res.set('Content-Type', 'image/jpeg');
      res.set('Cache-Control', 'public, max-age=86400');
      res.send(imageBuffer);
      console.log(`✅ Extracted and cached cover for: ${song.title}`);
    } else {
      console.log(`⚠️  No cover image found in: ${song.title}`);
      res.status(404).json({ success: false, message: 'No cover art found' });
    }
    
  } catch (error) {
    console.error('❌ Error extracting cover:', error.message);
    res.status(500).json({ success: false, message: 'Failed to extract cover' });
  }
});

// Stream song from MEGA (for MEGA mode) - direct streaming, no caching
app.get('/api/songs/stream/:songId', async (req, res) => {
  if (STORAGE_MODE !== 'mega') {
    return res.status(400).json({ success: false, message: 'Streaming only available in MEGA mode' });
  }
  
  const { songId } = req.params;
  
  try {
    const song = songsCache.find(s => s.id === songId);
    if (!song || !song.megaFile) {
      console.log(`❌ Song not found: ${songId}`);
      return res.status(404).json({ success: false, message: 'Song not found' });
    }
    
    console.log(`🎵 Streaming from MEGA: ${song.title}`);
    
    // Stream directly from MEGA (no caching)
    const megaStream = song.megaFile.download();
    
    // Set headers for streaming
    res.set('Content-Type', 'audio/flac');
    if (song.fileSize) {
      res.set('Content-Length', song.fileSize);
    }
    res.set('Accept-Ranges', 'bytes');
    res.set('Cache-Control', 'no-cache');
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Connection', 'keep-alive');
    
    // Handle client disconnect
    let streamDestroyed = false;
    
    req.on('close', () => {
      if (!streamDestroyed) {
        console.log(`🔌 Client disconnected: ${song.title}`);
        streamDestroyed = true;
        if (megaStream && !megaStream.destroyed) {
          megaStream.destroy();
        }
      }
    });
    
    // Pipe MEGA stream directly to response
    megaStream.pipe(res);
    
    megaStream.on('error', (error) => {
      if (!streamDestroyed) {
        console.error(`❌ MEGA stream error: ${error.message}`);
        streamDestroyed = true;
        if (!res.headersSent) {
          res.status(500).json({ success: false, message: 'Stream error' });
        }
      }
    });
    
    megaStream.on('end', () => {
      if (!streamDestroyed) {
        console.log(`✅ Finished streaming: ${song.title}`);
        streamDestroyed = true;
      }
    });
    
  } catch (error) {
    console.error('❌ Error streaming from MEGA:', error.message);
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: 'Failed to stream song' });
    }
  }
});

// ==================== AI ROUTES ====================

// Get song metadata (fetch from internet if not cached)
app.get('/api/songs/metadata/:songId', async (req, res) => {
  const { songId } = req.params;
  
  const song = songsCache.find(s => s.id === songId);
  if (!song) {
    return res.status(404).json({ success: false, message: 'Song not found' });
  }
  
  // Check cache first
  if (metadataCache[songId]) {
    console.log(`✅ Using cached metadata for: ${song.title}`);
    return res.json({ success: true, metadata: metadataCache[songId] });
  }
  
  // Fetch from internet
  console.log(`🌐 Fetching metadata from internet for: ${song.title}`);
  const metadata = await fetchSongMetadata(song.title, song.artist);
  
  if (metadata) {
    // Cache it
    metadataCache[songId] = metadata;
    saveMetadataCache();
    
    console.log(`✅ Fetched and cached metadata for: ${song.title}`);
    res.json({ success: true, metadata });
  } else {
    // Use basic metadata from file
    const basicMetadata = {
      genres: [song.genre],
      mood: song.mood,
      energy: song.energy,
      tempo: song.bpm,
      fetchedAt: new Date().toISOString()
    };
    
    metadataCache[songId] = basicMetadata;
    saveMetadataCache();
    
    res.json({ success: true, metadata: basicMetadata });
  }
});

// AI Sync - Get similar songs (using cached metadata)
app.post('/api/ai/similar', async (req, res) => {
  const { songId } = req.body;
  
  const currentSong = songsCache.find(s => s.id === songId);
  if (!currentSong) {
    return res.status(404).json({ success: false, message: 'Song not found' });
  }
  
  // Get metadata for current song (fetch if not cached)
  let currentMetadata = metadataCache[songId];
  if (!currentMetadata) {
    console.log(`🌐 Fetching metadata for current song: ${currentSong.title}`);
    currentMetadata = await fetchSongMetadata(currentSong.title, currentSong.artist);
    if (currentMetadata) {
      metadataCache[songId] = currentMetadata;
      saveMetadataCache();
    } else {
      currentMetadata = {
        genres: [currentSong.genre],
        mood: currentSong.mood,
        energy: currentSong.energy,
        tempo: currentSong.bpm
      };
    }
  }
  
  // Calculate similarity with all other songs
  const similarSongs = [];
  
  for (const song of songsCache) {
    if (song.id === songId) continue;
    
    // Get metadata for this song
    let songMetadata = metadataCache[song.id];
    if (!songMetadata) {
      // Use basic metadata from file
      songMetadata = {
        genres: [song.genre],
        mood: song.mood,
        energy: song.energy,
        tempo: song.bpm
      };
    }
    
    // Calculate similarity score
    const similarity = calculateAdvancedSimilarity(currentMetadata, songMetadata);
    
    similarSongs.push({
      ...song,
      similarity
    });
  }
  
  // Sort by similarity and return top 20
  similarSongs.sort((a, b) => b.similarity - a.similarity);
  const topSongs = similarSongs.slice(0, 20);
  
  console.log(`🎯 Found ${topSongs.length} similar songs for: ${currentSong.title}`);
  
  res.json({ success: true, songs: topSongs });
});

// Helper: Calculate advanced similarity using metadata (enhanced with emotions)
function calculateAdvancedSimilarity(metadata1, metadata2) {
  let score = 100;
  
  // Emotion similarity (40% weight) - NEW!
  if (metadata1.emotions && metadata2.emotions) {
    const emotions1 = metadata1.emotions || [];
    const emotions2 = metadata2.emotions || [];
    const emotionMatch = emotions1.some(e1 => 
      emotions2.some(e2 => e1.toLowerCase() === e2.toLowerCase())
    );
    if (!emotionMatch) {
      score -= 40;
    }
  } else {
    // Fallback to mood if emotions not available
    if (metadata1.mood !== metadata2.mood) {
      score -= 40;
    }
  }
  
  // Genre similarity (30% weight)
  const genres1 = metadata1.genres || [];
  const genres2 = metadata2.genres || [];
  const genreMatch = genres1.some(g1 => 
    genres2.some(g2 => g1.toLowerCase() === g2.toLowerCase())
  );
  if (!genreMatch) {
    score -= 30;
  }
  
  // Energy similarity (20% weight)
  const energyDiff = Math.abs((metadata1.energy || 0.6) - (metadata2.energy || 0.6));
  score -= energyDiff * 20;
  
  // Tempo similarity (10% weight)
  const tempoDiff = Math.abs((metadata1.tempo || 120) - (metadata2.tempo || 120));
  score -= Math.min(tempoDiff * 0.1, 10);
  
  return Math.max(score, 0);
}

// Get AI suggestions for Smart Modes
app.post('/api/ai/smart-mode', (req, res) => {
  const { mode, userId } = req.body; // mode: 'gym', 'study', 'drive'
  
  let filteredSongs = [];
  
  switch(mode) {
    case 'gym':
      // High energy, high BPM
      filteredSongs = songsCache.filter(s => s.energy >= 0.7 && s.bpm >= 120);
      break;
    case 'study':
      // Low energy, calm
      filteredSongs = songsCache.filter(s => s.energy <= 0.5 && s.bpm <= 100);
      break;
    case 'drive':
      // Medium energy, steady BPM
      filteredSongs = songsCache.filter(s => s.energy >= 0.5 && s.energy <= 0.8);
      break;
    default:
      filteredSongs = songsCache;
  }
  
  res.json({ success: true, songs: filteredSongs });
});

// Analyze all songs - Fetch metadata for all songs (run once to populate cache)
app.post('/api/ai/analyze-all', async (req, res) => {
  console.log('🤖 Starting AI analysis for all songs...');
  
  let analyzed = 0;
  let cached = 0;
  let failed = 0;
  
  for (const song of songsCache) {
    // Skip if already cached
    if (metadataCache[song.id]) {
      cached++;
      continue;
    }
    
    try {
      console.log(`🔍 Analyzing: ${song.title} - ${song.artist}`);
      const metadata = await fetchSongMetadata(song.title, song.artist);
      
      if (metadata) {
        metadataCache[song.id] = metadata;
        analyzed++;
        console.log(`✅ ${analyzed}/${songsCache.length - cached}: ${song.title} → ${metadata.mood} (${metadata.emotions?.join(', ')})`);
      } else {
        // Use basic metadata
        metadataCache[song.id] = {
          genres: [song.genre],
          mood: song.mood,
          energy: song.energy,
          emotions: [song.mood],
          tempo: song.bpm,
          source: 'fallback',
          fetchedAt: new Date().toISOString()
        };
        failed++;
      }
      
      // Save cache every 5 songs
      if ((analyzed + failed) % 5 === 0) {
        saveMetadataCache();
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.error(`❌ Error analyzing ${song.title}:`, error.message);
      failed++;
    }
  }
  
  // Final save
  saveMetadataCache();
  
  console.log(`\n✅ Analysis complete!`);
  console.log(`📊 Analyzed: ${analyzed}, Cached: ${cached}, Failed: ${failed}`);
  
  res.json({ 
    success: true, 
    analyzed, 
    cached, 
    failed,
    total: songsCache.length 
  });
});

// Get AI Vibe suggestions (dynamic playlists based on time/mood)
app.post('/api/ai/vibes', (req, res) => {
  const { userId, timeOfDay, mood } = req.body;
  
  console.log(`🎵 Generating vibe suggestions for ${timeOfDay || 'any time'}, mood: ${mood || 'any'}`);
  
  // Get current hour if not provided
  const hour = timeOfDay ? parseInt(timeOfDay) : new Date().getHours();
  
  let vibes = [];
  
  // Morning Vibes (6am - 12pm)
  if (hour >= 6 && hour < 12) {
    const morningSongs = songsCache.filter(s => {
      const meta = metadataCache[s.id] || { mood: s.mood, energy: s.energy };
      return meta.energy >= 0.6 && meta.energy <= 0.8 && 
             ['happy', 'energetic', 'neutral'].includes(meta.mood);
    }).slice(0, 20);
    
    vibes.push({
      id: 'morning_energy',
      title: 'Morning Energy',
      subtitle: 'Start your day right',
      mood: 'energetic',
      timeOfDay: 'morning',
      songs: cleanSongs(morningSongs)
    });
  }
  
  // Afternoon Vibes (12pm - 6pm)
  else if (hour >= 12 && hour < 18) {
    const afternoonSongs = songsCache.filter(s => {
      const meta = metadataCache[s.id] || { mood: s.mood, energy: s.energy };
      return meta.energy >= 0.5 && meta.energy <= 0.7;
    }).slice(0, 20);
    
    vibes.push({
      id: 'afternoon_flow',
      title: 'Afternoon Flow',
      subtitle: 'Keep the momentum going',
      mood: 'neutral',
      timeOfDay: 'afternoon',
      songs: cleanSongs(afternoonSongs)
    });
  }
  
  // Evening Vibes (6pm - 10pm)
  else if (hour >= 18 && hour < 22) {
    const eveningSongs = songsCache.filter(s => {
      const meta = metadataCache[s.id] || { mood: s.mood, energy: s.energy };
      return meta.energy >= 0.4 && meta.energy <= 0.6;
    }).slice(0, 20);
    
    vibes.push({
      id: 'evening_chill',
      title: 'Evening Chill',
      subtitle: 'Wind down your day',
      mood: 'calm',
      timeOfDay: 'evening',
      songs: cleanSongs(eveningSongs)
    });
  }
  
  // Night Vibes (10pm - 6am)
  else {
    const nightSongs = songsCache.filter(s => {
      const meta = metadataCache[s.id] || { mood: s.mood, energy: s.energy };
      return meta.energy <= 0.5 && ['calm', 'sad', 'neutral'].includes(meta.mood);
    }).slice(0, 20);
    
    vibes.push({
      id: 'midnight_thoughts',
      title: 'Midnight Thoughts',
      subtitle: 'Late night vibes',
      mood: 'calm',
      timeOfDay: 'night',
      songs: cleanSongs(nightSongs)
    });
  }
  
  // Add mood-based vibes
  if (mood) {
    const moodSongs = songsCache.filter(s => {
      const meta = metadataCache[s.id] || { mood: s.mood };
      return meta.mood === mood || meta.emotions?.includes(mood);
    }).slice(0, 20);
    
    vibes.push({
      id: `mood_${mood}`,
      title: `${mood.charAt(0).toUpperCase() + mood.slice(1)} Vibes`,
      subtitle: `Feeling ${mood}`,
      mood: mood,
      songs: cleanSongs(moodSongs)
    });
  }
  
  // Add "Lost in Thought" vibe (melancholic/emotional)
  const thoughtfulSongs = songsCache.filter(s => {
    const meta = metadataCache[s.id] || { mood: s.mood, energy: s.energy };
    return ['sad', 'calm'].includes(meta.mood) && meta.energy <= 0.5;
  }).slice(0, 20);
  
  vibes.push({
    id: 'lost_in_thought',
    title: 'Lost in Thought',
    subtitle: 'Deep focus and contemplation',
    mood: 'calm',
    songs: cleanSongs(thoughtfulSongs)
  });
  
  // Add "Neon Lights" vibe (energetic/electronic)
  const neonSongs = songsCache.filter(s => {
    const meta = metadataCache[s.id] || { mood: s.mood, energy: s.energy };
    return meta.energy >= 0.7 && ['energetic', 'happy'].includes(meta.mood);
  }).slice(0, 20);
  
  vibes.push({
    id: 'neon_lights',
    title: 'Neon Lights',
    subtitle: 'Cyberpunk energy and electric beats',
    mood: 'energetic',
    songs: cleanSongs(neonSongs)
  });
  
  console.log(`✅ Generated ${vibes.length} vibe playlists`);
  res.json({ success: true, vibes });
});

// ==================== PLAYLISTS ROUTES (THE SHELF) ====================

// Get user playlists
app.get('/api/playlists/:userId', (req, res) => {
  const { userId } = req.params;
  const playlists = readJSON(PLAYLISTS_DB);
  
  const userPlaylists = playlists.filter(p => p.userId === userId);
  
  res.json({ success: true, playlists: userPlaylists });
});

// Create playlist
app.post('/api/playlists/create', (req, res) => {
  const { userId, name, description, imageUrl } = req.body;
  const playlists = readJSON(PLAYLISTS_DB);
  
  const newPlaylist = {
    id: `playlist_${Date.now()}`,
    userId,
    name,
    description: description || '',
    imageUrl: imageUrl || null,
    songs: [], // Array of song IDs
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  
  playlists.push(newPlaylist);
  writeJSON(PLAYLISTS_DB, playlists);
  
  console.log(`✅ Created playlist: ${name} for user ${userId}`);
  res.json({ success: true, playlist: newPlaylist });
});

// Add song to playlist
app.post('/api/playlists/add-song', (req, res) => {
  const { playlistId, songId } = req.body;
  const playlists = readJSON(PLAYLISTS_DB);
  
  const playlist = playlists.find(p => p.id === playlistId);
  if (!playlist) {
    return res.status(404).json({ success: false, message: 'Playlist not found' });
  }
  
  // Check if song already in playlist
  if (playlist.songs.includes(songId)) {
    return res.json({ success: true, message: 'Song already in playlist', playlist });
  }
  
  playlist.songs.push(songId);
  playlist.updatedAt = new Date().toISOString();
  writeJSON(PLAYLISTS_DB, playlists);
  
  console.log(`✅ Added song ${songId} to playlist ${playlist.name}`);
  res.json({ success: true, playlist });
});

// Remove song from playlist
app.post('/api/playlists/remove-song', (req, res) => {
  const { playlistId, songId } = req.body;
  const playlists = readJSON(PLAYLISTS_DB);
  
  const playlist = playlists.find(p => p.id === playlistId);
  if (!playlist) {
    return res.status(404).json({ success: false, message: 'Playlist not found' });
  }
  
  playlist.songs = playlist.songs.filter(id => id !== songId);
  playlist.updatedAt = new Date().toISOString();
  writeJSON(PLAYLISTS_DB, playlists);
  
  console.log(`✅ Removed song ${songId} from playlist ${playlist.name}`);
  res.json({ success: true, playlist });
});

// Delete playlist
app.delete('/api/playlists/delete/:playlistId', (req, res) => {
  const { playlistId } = req.params;
  let playlists = readJSON(PLAYLISTS_DB);
  
  const playlist = playlists.find(p => p.id === playlistId);
  if (!playlist) {
    return res.status(404).json({ success: false, message: 'Playlist not found' });
  }
  
  playlists = playlists.filter(p => p.id !== playlistId);
  writeJSON(PLAYLISTS_DB, playlists);
  
  console.log(`✅ Deleted playlist: ${playlist.name}`);
  res.json({ success: true, message: 'Playlist deleted' });
});

// Get playlist songs (with full song data)
app.get('/api/playlists/:playlistId/songs', (req, res) => {
  const { playlistId } = req.params;
  const playlists = readJSON(PLAYLISTS_DB);
  
  const playlist = playlists.find(p => p.id === playlistId);
  if (!playlist) {
    return res.status(404).json({ success: false, message: 'Playlist not found' });
  }
  
  // Get full song data for each song ID
  const playlistSongs = playlist.songs
    .map(songId => {
      const song = songsCache.find(s => s.id === songId);
      if (!song) return null;
      // Remove megaFile to avoid circular reference
      const { megaFile, ...songWithoutMegaFile } = song;
      return songWithoutMegaFile;
    })
    .filter(song => song !== null);
  
  res.json({ success: true, songs: playlistSongs, playlist });
});

// ==================== PROFILE ROUTES ====================

// Get user profile
app.get('/api/profile/:userId', (req, res) => {
  const { userId } = req.params;
  const users = readJSON(USERS_DB);
  
  const user = users.find(u => u.id === userId);
  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }
  
  res.json({
    success: true,
    profile: {
      id: user.id,
      email: user.email,
      username: user.username,
      plan: user.plan,
      storageUsed: user.storageUsed,
      storageLimit: user.storageLimit,
      likedSongsCount: user.likedSongs.length,
      playlistsCount: user.playlists.length
    }
  });
});

// ==================== HEALTH CHECK ====================

app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'AXOR Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🎵 AXOR Backend running on http://localhost:${PORT}`);
  console.log(`📁 Music library: ${MUSIC_LIBRARY_PATH}`);
  console.log(`📊 Database path: ${DB_PATH}`);
  console.log(`\n🔍 Scanning your music library...`);
});