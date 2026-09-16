"use client";

import { useEffect, useState } from 'react';
import { getPitches, getPitch } from '@/lib/api';
import { Calendar, Clock, DollarSign, Users, ChevronLeft, X, MapPin } from 'lucide-react';

interface Pitch {
  id: string;
  name: string;
  description: string;
  location: string;
  surface: string;
  indoor: boolean;
  amenities: string[];
  pricePerHour: number;
  images: string[];
  bookings?: any[];
}

function StatCard({ icon: Icon, iconBg, iconColor, label, value }: any) {
  return (
    <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center gap-4">
      <div className={`p-3 ${iconBg} rounded-full`}>
        <Icon className={`w-6 h-6 ${iconColor}`} />
      </div>
      <div>
        <p className="text-sm text-gray-500 font-medium">{label}</p>
        <p className="text-2xl font-bold">{value}</p>
      </div>
    </div>
  );
}

function SlotTimeline({ pitch }: { pitch: Pitch }) {
  const hours = Array.from({ length: 12 }, (_, i) => i + 10); // 10:00 to 21:00
  const bookings = pitch.bookings || [];

  const isBooked = (hour: number) => {
    return bookings.some((b: any) => {
      const start = new Date(b.startTime);
      return start.getHours() === hour;
    });
  };

  return (
    <div className="mt-4">
      <h4 className="text-sm font-bold text-gray-700 mb-2">المواعيد اليوم:</h4>
      <div className="flex flex-wrap gap-2">
        {hours.map((h) => {
          const booked = isBooked(h);
          return (
            <div
              key={h}
              className={`px-3 py-2 rounded-lg text-sm font-mono font-bold border ${
                booked
                  ? 'bg-red-50 border-red-300 text-red-600 line-through'
                  : 'bg-green-50 border-green-300 text-green-700 cursor-pointer hover:bg-green-100'
              }`}
            >
              {h}:00
            </div>
          );
        })}
      </div>
      <div className="flex gap-4 mt-2 text-xs text-gray-500">
        <span className="flex items-center gap-1"><span className="w-3 h-3 bg-green-200 rounded inline-block"></span>متاح</span>
        <span className="flex items-center gap-1"><span className="w-3 h-3 bg-red-200 rounded inline-block"></span>محجوز</span>
      </div>
    </div>
  );
}

export default function Dashboard() {
  const [pitches, setPitches] = useState<Pitch[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedPitch, setSelectedPitch] = useState<Pitch | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  useEffect(() => {
    getPitches()
      .then((data) => {
        setPitches(data);
        setLoading(false);
      })
      .catch(() => {
        setError('فشل تحميل البيانات. تأكد أن السيرفر يعمل على المنفذ 3001.');
        setLoading(false);
      });
  }, []);

  const openPitchDetail = async (id: string) => {
    setDetailLoading(true);
    try {
      const data = await getPitch(id);
      setSelectedPitch(data);
    } catch {
      setError('فشل تحميل تفاصيل الملعب');
    } finally {
      setDetailLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900" dir="rtl">
      {/* Header */}
      <header className="bg-white shadow-sm border-b sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16 items-center">
            <h1 className="text-2xl font-bold text-green-600">⚽ PitchUp لوحة التحكم</h1>
            <span className="text-sm text-gray-500">مرحباً، مالك الملعب</span>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Stats */}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-8">
          <StatCard icon={DollarSign} iconBg="bg-green-100" iconColor="text-green-600" label="أرباح اليوم" value="1,200 ج.م" />
          <StatCard icon={Calendar} iconBg="bg-blue-100" iconColor="text-blue-600" label="حجوزات اليوم" value="8 حجوزات" />
          <StatCard icon={Clock} iconBg="bg-orange-100" iconColor="text-orange-600" label="الساعات المتاحة" value="4 ساعات" />
          <StatCard icon={Users} iconBg="bg-purple-100" iconColor="text-purple-600" label="طلبات إيجاد لاعب" value="2 طلبات" />
        </div>

        {/* Error */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded-lg mb-6">
            {error}
          </div>
        )}

        {/* Pitch Detail Modal */}
        {selectedPitch && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
              <div className="relative">
                <img src={selectedPitch.images[0]} alt={selectedPitch.name} className="w-full h-56 object-cover rounded-t-2xl" />
                <button
                  onClick={() => setSelectedPitch(null)}
                  className="absolute top-3 left-3 bg-white/80 rounded-full p-1.5 hover:bg-white"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="p-6">
                <h2 className="text-2xl font-bold mb-2">{selectedPitch.name}</h2>
                <p className="text-gray-500 flex items-center gap-1 mb-3"><MapPin className="w-4 h-4" />{selectedPitch.location}</p>
                <p className="text-gray-700 mb-4">{selectedPitch.description}</p>
                <div className="flex flex-wrap gap-2 mb-4">
                  {selectedPitch.amenities.map((a, i) => (
                    <span key={i} className="bg-gray-100 text-gray-700 px-3 py-1 rounded-full text-sm">{a}</span>
                  ))}
                </div>
                <div className="flex justify-between items-center mb-4">
                  <span className="text-sm bg-blue-50 text-blue-700 px-3 py-1 rounded-full">{selectedPitch.surface} • {selectedPitch.indoor ? 'داخلي' : 'خارجي'}</span>
                  <span className="text-lg font-bold text-green-600">{selectedPitch.pricePerHour} ج.م / ساعة</span>
                </div>
                <SlotTimeline pitch={selectedPitch} />
              </div>
            </div>
          </div>
        )}

        {/* Pitch List */}
        <h2 className="text-xl font-bold mb-4">ملاعبي</h2>
        {loading ? (
          <div className="flex justify-center py-12">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-green-600"></div>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {pitches.map((pitch) => (
              <div key={pitch.id} className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition">
                <img
                  src={pitch.images?.[0] || ''}
                  alt={pitch.name}
                  className="w-full h-48 object-cover"
                  onError={(e: any) => { e.target.src = 'https://placehold.co/600x400/e2e8f0/94a3b8?text=No+Image'; }}
                />
                <div className="p-4">
                  <h3 className="text-lg font-bold mb-1">{pitch.name}</h3>
                  <p className="text-sm text-gray-500 flex items-center gap-1 mb-3"><MapPin className="w-3 h-3" />{pitch.location}</p>
                  <div className="flex justify-between items-center text-sm mb-3">
                    <span className="bg-gray-100 px-2 py-1 rounded">{pitch.surface}</span>
                    <span className="font-bold text-green-600">{pitch.pricePerHour} ج.م / ساعة</span>
                  </div>
                  <button
                    onClick={() => openPitchDetail(pitch.id)}
                    className="w-full bg-green-600 text-white py-2.5 rounded-lg hover:bg-green-700 transition flex items-center justify-center gap-2"
                  >
                    إدارة المواعيد <ChevronLeft className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
