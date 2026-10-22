/**
 * Google Live voice is not used.
 * Voice and video calls answer with gpt-5-mini and speak with the app voice.
 */
export const GeminiLiveService = {
  isConfigured() {
    return false;
  },

  async createClientSecret() {
    const err = new Error('voice_live_unavailable');
    err.status = 410;
    throw err;
  },
};
