import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:3001/api',
});

export const getPitches = () => api.get('/pitches').then(res => res.data);
export const getPitch = (id: string) => api.get(`/pitches/${id}`).then(res => res.data);
export const createBooking = (data: any) => api.post('/bookings', data).then(res => res.data);
export const getMatchRequests = () => api.get('/match-requests').then(res => res.data);

export default api;
