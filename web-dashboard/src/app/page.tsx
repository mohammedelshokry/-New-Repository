"use client";

import { useEffect, useState } from 'react';
import {
  getAdminStats,
  getPitches,
  getAdminBookings,
  getUsers,
  deletePitch,
  deleteUser,
} from '@/lib/api';
import {
  ShieldCheck,
  DollarSign,
  Users,
  Calendar,
  Trash2,
  MapPin,
  CheckCircle,
  TrendingUp,
  Award,
} from 'lucide-react';

export default function MasterAdminDashboard() {
  const [activeTab, setActiveTab] = useState<'overview' | 'pitches' | 'users' | 'bookings'>('overview');
  const [stats, setStats] = useState<any>(null);
  const [pitches, setPitches] = useState<any[]>([]);
  const [users, setUsers] = useState<any[]>([]);
  const [bookings, setBookings] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const [statsData, pitchesData, usersData, bookingsData] = await Promise.all([
        getAdminStats(),
        getPitches(),
        getUsers(),
        getAdminBookings(),
      ]);
      setStats(statsData);
      setPitches(pitchesData);
      setUsers(usersData);
      setBookings(bookingsData);
    } catch (err) {
      console.error('Failed to load admin data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleDeletePitch = async (id: string, name: string) => {
    if (!confirm(`هل أنت متأكد من حذف ملعب "${name}" نهائياً من المنصة؟`)) return;
    try {
      await deletePitch(id);
      setPitches(pitches.filter(p => p.id !== id));
      alert('تم حذف الملعب بنجاح!');
    } catch {
      alert('فشل حذف الملعب');
    }
  };

  const handleDeleteUser = async (id: string, name: string) => {
    if (!confirm(`هل أنت متأكد من حذف/حظر المستخدم "${name}"؟`)) return;
    try {
      await deleteUser(id);
      setUsers(users.filter(u => u.id !== id));
      alert('تم حذف المستخدم بنجاح!');
    } catch {
      alert('فشل حذف المستخدم');
    }
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 font-sans" dir="rtl">
      {/* Top Super Admin Nav */}
      <header className="bg-slate-800/80 backdrop-blur border-b border-slate-700 sticky top-0 z-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="bg-emerald-500/20 p-2 rounded-xl text-emerald-400 border border-emerald-500/30">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-lg font-bold text-white flex items-center gap-2">
                PitchUp <span className="bg-emerald-500 text-slate-950 text-xs px-2 py-0.5 rounded-full font-black">SUPER ADMIN</span>
              </h1>
              <p className="text-xs text-slate-400">لوحة الإدارة العليا والتحكم المركزي للمدينة</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <span className="text-xs bg-slate-700/60 px-3 py-1.5 rounded-lg text-emerald-400 font-mono border border-slate-600 flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              السيرفر متصل أونلاين
            </span>
            <button
              onClick={loadData}
              className="text-xs bg-slate-700 hover:bg-slate-600 px-3 py-1.5 rounded-lg text-slate-200 transition"
            >
              تحديث البيانات
            </button>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex gap-8 border-t border-slate-700/50 text-sm font-medium">
          <button
            onClick={() => setActiveTab('overview')}
            className={`py-3 border-b-2 transition flex items-center gap-2 ${
              activeTab === 'overview' ? 'border-emerald-400 text-emerald-400 font-bold' : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <TrendingUp className="w-4 h-4" /> نظرة عامة والأرباح
          </button>
          <button
            onClick={() => setActiveTab('pitches')}
            className={`py-3 border-b-2 transition flex items-center gap-2 ${
              activeTab === 'pitches' ? 'border-emerald-400 text-emerald-400 font-bold' : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <Award className="w-4 h-4" /> كل الملاعب ({pitches.length})
          </button>
          <button
            onClick={() => setActiveTab('users')}
            className={`py-3 border-b-2 transition flex items-center gap-2 ${
              activeTab === 'users' ? 'border-emerald-400 text-emerald-400 font-bold' : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <Users className="w-4 h-4" /> اللاعبين والشركاء ({users.length})
          </button>
          <button
            onClick={() => setActiveTab('bookings')}
            className={`py-3 border-b-2 transition flex items-center gap-2 ${
              activeTab === 'bookings' ? 'border-emerald-400 text-emerald-400 font-bold' : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <Calendar className="w-4 h-4" /> سجل الحجوزات المباشر ({bookings.length})
          </button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {loading ? (
          <div className="flex justify-center items-center py-32">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-400"></div>
          </div>
        ) : (
          <>
            {/* 1. OVERVIEW TAB */}
            {activeTab === 'overview' && (
              <div className="space-y-8">
                {/* Stats Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                  <div className="bg-slate-800/90 border border-slate-700/80 p-5 rounded-2xl">
                    <div className="flex items-center justify-between text-slate-400 text-sm mb-3">
                      <span>إجمالي عمولة المنصة (10%)</span>
                      <DollarSign className="w-5 h-5 text-emerald-400" />
                    </div>
                    <p className="text-3xl font-black text-emerald-400">
                      {(stats?.platformCommission || 0).toLocaleString()} ج.م
                    </p>
                    <p className="text-xs text-slate-400 mt-2">من إجمالي حركات حجز بقيمة {(stats?.totalRevenue || 0).toLocaleString()} ج.م</p>
                  </div>

                  <div className="bg-slate-800/90 border border-slate-700/80 p-5 rounded-2xl">
                    <div className="flex items-center justify-between text-slate-400 text-sm mb-3">
                      <span>إجمالي الحجوزات</span>
                      <Calendar className="w-5 h-5 text-blue-400" />
                    </div>
                    <p className="text-3xl font-black text-white">{stats?.totalBookings || 0}</p>
                    <p className="text-xs text-slate-400 mt-2">حجز مؤكد في ملاعب المدينة</p>
                  </div>

                  <div className="bg-slate-800/90 border border-slate-700/80 p-5 rounded-2xl">
                    <div className="flex items-center justify-between text-slate-400 text-sm mb-3">
                      <span>ملاعب المدينة المعتمدة</span>
                      <Award className="w-5 h-5 text-purple-400" />
                    </div>
                    <p className="text-3xl font-black text-white">{stats?.totalPitches || 0}</p>
                    <p className="text-xs text-slate-400 mt-2">كرة قدم، بادل، بلياردو، جيم</p>
                  </div>

                  <div className="bg-slate-800/90 border border-slate-700/80 p-5 rounded-2xl">
                    <div className="flex items-center justify-between text-slate-400 text-sm mb-3">
                      <span>المستخدمين المسجلين</span>
                      <Users className="w-5 h-5 text-amber-400" />
                    </div>
                    <p className="text-3xl font-black text-white">{stats?.totalUsers || 0}</p>
                    <p className="text-xs text-slate-400 mt-2">
                      {stats?.totalPlayers || 0} لاعب • {stats?.totalOwners || 0} صاحب منشأة
                    </p>
                  </div>
                </div>

                {/* Live Activity Box */}
                <div className="bg-slate-800/90 border border-slate-700 p-6 rounded-2xl">
                  <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                    <CheckCircle className="w-5 h-5 text-emerald-400" /> أحدث الحجوزات المباشرة في مدينتك
                  </h3>
                  <div className="divide-y divide-slate-700/50">
                    {bookings.slice(0, 5).map((b) => (
                      <div key={b.id} className="py-3 flex items-center justify-between text-sm">
                        <div>
                          <p className="font-bold text-slate-200">{b.user?.name} (هاتف: {b.user?.phone})</p>
                          <p className="text-xs text-slate-400">{b.pitch?.name} • {b.pitch?.location}</p>
                        </div>
                        <div className="text-left">
                          <span className="text-emerald-400 font-bold font-mono">{b.pitch?.pricePerHour} ج.م</span>
                          <p className="text-xs text-slate-400">
                            {new Date(b.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* 2. PITCHES TAB */}
            {activeTab === 'pitches' && (
              <div className="space-y-4">
                <div className="flex justify-between items-center mb-2">
                  <h2 className="text-xl font-bold text-white">كل الملاعب المضافة على التطبيق</h2>
                  <span className="text-xs text-slate-400">تحكم كامل بحذف أو مراجعة أي ملعب</span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {pitches.map((p) => (
                    <div key={p.id} className="bg-slate-800 border border-slate-700 rounded-2xl overflow-hidden group hover:border-slate-600 transition">
                      <img src={p.images?.[0] || ''} alt={p.name} className="w-full h-44 object-cover" />
                      <div className="p-5">
                        <div className="flex justify-between items-start mb-2">
                          <h3 className="text-lg font-bold text-white">{p.name}</h3>
                          <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-2 py-0.5 rounded text-xs font-bold">
                            {p.pricePerHour} ج.م / ساعة
                          </span>
                        </div>
                        <p className="text-xs text-slate-400 flex items-center gap-1 mb-3">
                          <MapPin className="w-3.5 h-3.5" /> {p.location}
                        </p>
                        <div className="flex flex-wrap gap-1.5 mb-4">
                          <span className="bg-slate-700 px-2 py-0.5 rounded text-xs text-slate-300">{p.surface}</span>
                          {p.indoor && <span className="bg-blue-900/60 text-blue-300 px-2 py-0.5 rounded text-xs">صالة مغطاة</span>}
                        </div>
                        <button
                          onClick={() => handleDeletePitch(p.id, p.name)}
                          className="w-full bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 py-2 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2"
                        >
                          <Trash2 className="w-4 h-4" /> حذف الملعب نهائياً
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* 3. USERS TAB */}
            {activeTab === 'users' && (
              <div className="bg-slate-800 border border-slate-700 rounded-2xl overflow-hidden">
                <div className="p-6 border-b border-slate-700 flex justify-between items-center">
                  <h2 className="text-lg font-bold text-white">قائمة جميع المسجلين في مدينتك</h2>
                  <span className="text-xs text-slate-400">إجمالي {users.length} مستخدم</span>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-right text-sm">
                    <thead className="bg-slate-900/50 text-slate-400 text-xs uppercase border-b border-slate-700">
                      <tr>
                        <th className="py-3.5 px-6">الاسم</th>
                        <th className="py-3.5 px-6">رقم الهاتف</th>
                        <th className="py-3.5 px-6">نوع الحساب</th>
                        <th className="py-3.5 px-6">تاريخ الانضمام</th>
                        <th className="py-3.5 px-6 text-center">إجراءات</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-700/50">
                      {users.map((u) => (
                        <tr key={u.id} className="hover:bg-slate-750 transition">
                          <td className="py-4 px-6 font-medium text-white">{u.name}</td>
                          <td className="py-4 px-6 font-mono text-slate-300">{u.phone}</td>
                          <td className="py-4 px-6">
                            <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                              u.role === 'OWNER' ? 'bg-purple-500/10 text-purple-400 border border-purple-500/20' : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                            }`}>
                              {u.role === 'OWNER' ? 'صاحب ملعب' : 'لاعب'}
                            </span>
                          </td>
                          <td className="py-4 px-6 text-xs text-slate-400">
                            {new Date(u.createdAt).toLocaleDateString('ar-EG')}
                          </td>
                          <td className="py-4 px-6 text-center">
                            <button
                              onClick={() => handleDeleteUser(u.id, u.name)}
                              className="text-red-400 hover:text-red-300 p-1.5 rounded-lg hover:bg-red-500/10 transition"
                              title="حذف المستخدم"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* 4. BOOKINGS TAB */}
            {activeTab === 'bookings' && (
              <div className="bg-slate-800 border border-slate-700 rounded-2xl overflow-hidden">
                <div className="p-6 border-b border-slate-700">
                  <h2 className="text-lg font-bold text-white">سجل جميع الحجوزات</h2>
                  <p className="text-xs text-slate-400">متابعة لحظية لكل حجز تم في الملاعب</p>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-right text-sm">
                    <thead className="bg-slate-900/50 text-slate-400 text-xs uppercase border-b border-slate-700">
                      <tr>
                        <th className="py-3.5 px-6">اللاعب</th>
                        <th className="py-3.5 px-6">الملعب</th>
                        <th className="py-3.5 px-6">توقيت الحجز</th>
                        <th className="py-3.5 px-6">قيمة الحجز</th>
                        <th className="py-3.5 px-6">عمولة المنصة</th>
                        <th className="py-3.5 px-6">الحالة</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-700/50">
                      {bookings.map((b) => (
                        <tr key={b.id} className="hover:bg-slate-750 transition">
                          <td className="py-4 px-6">
                            <p className="font-bold text-white">{b.user?.name}</p>
                            <p className="text-xs text-slate-400">{b.user?.phone}</p>
                          </td>
                          <td className="py-4 px-6">
                            <p className="font-medium text-slate-200">{b.pitch?.name}</p>
                            <p className="text-xs text-slate-400">{b.pitch?.location}</p>
                          </td>
                          <td className="py-4 px-6 text-xs text-slate-300">
                            {new Date(b.startTime).toLocaleString('ar-EG', { dateStyle: 'short', timeStyle: 'short' })}
                          </td>
                          <td className="py-4 px-6 font-mono font-bold text-white">
                            {b.pitch?.pricePerHour} ج.م
                          </td>
                          <td className="py-4 px-6 font-mono font-bold text-emerald-400">
                            {Math.round((b.pitch?.pricePerHour || 0) * 0.10)} ج.م
                          </td>
                          <td className="py-4 px-6">
                            <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-2 py-0.5 rounded text-xs font-bold">
                              {b.status}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  );
}
