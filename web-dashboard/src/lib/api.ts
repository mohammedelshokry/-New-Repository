import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:3001/api',
});

// General
export const getPitches = () => api.get('/pitches').then(res => res.data);
export const getPitch = (id: string) => api.get(`/pitches/${id}`).then(res => res.data);
export const createBooking = (data: any) => api.post('/bookings', data).then(res => res.data);
export const getMatchRequests = () => api.get('/match-requests').then(res => res.data);

// Super Admin Master Endpoints
export const getAdminStats = () => api.get('/admin/stats').then(res => res.data);
export const getAdminBookings = () => api.get('/admin/bookings').then(res => res.data);
export const getUsers = () => api.get('/users').then(res => res.data);
export const deletePitch = (id: string) => api.delete(`/admin/pitches/${id}`).then(res => res.data);
export const deleteUser = (id: string) => api.delete(`/admin/users/${id}`).then(res => res.data);

export default api;
