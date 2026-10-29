import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Location from 'expo-location';
import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import { WILAYAS_FR, type Language } from './i18n';

export type Role = 'user' | 'admin';
export type VehicleType = 'car' | 'motorcycle';
export type ResponseService = 'police' | 'civilProtection';
export type AlertStage =
  | 'Test recorded'
  | 'Test received'
  | 'Test team dispatched'
  | 'Test arrived'
  | 'Test resolved';

export interface Profile {
  fullName: string;
  username: string;
  phone: string;
  wilaya: string;
  role: Role;
  createdAt?: string;
}

export interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
}

export interface AlertRecord {
  id: string;
  createdAt: string;
  latitude: number | null;
  longitude: number | null;
  wilaya: string;
  vehicleType: VehicleType;
  stage: AlertStage;
  responseTimestamps: Partial<Record<AlertStage, string>>;
  serviceStatus?: Record<ResponseService, AlertStage>;
  serviceStatusTimestamps?: Record<ResponseService, Partial<Record<AlertStage, string>>>;
}

export interface WilayaNumbers {
  id: string;
  wilaya: string;
  police: string;
  civilProtection: string;
}

export interface AppData {
  profile: Profile | null;
  knownUsers: Profile[];
  disabledUsers: string[];
  role: Role;
  language: Language;
  vehicleType: VehicleType;
  wilaya: string;
  testMode: boolean;
  deviceConnected: boolean;
  contacts: EmergencyContact[];
  alerts: AlertRecord[];
  wilayaNumbers: WilayaNumbers[];
  currentLocation: { latitude: number; longitude: number } | null;
}

interface AppContextValue {
  data: AppData;
  ready: boolean;
  storageError: boolean;
  locationError: string | null;
  createProfile: (profile: Omit<Profile, 'role'>) => void;
  startDemo: (role: Role, username?: string) => boolean;
  signOut: () => void;
  patchProfile: (patch: Partial<Pick<Profile, 'fullName' | 'phone' | 'wilaya'>>) => void;
  patchData: (patch: Partial<AppData>) => void;
  addContact: (contact: Omit<EmergencyContact, 'id'>) => void;
  updateContact: (contact: EmergencyContact) => void;
  deleteContact: (id: string) => void;
  addTestAlert: () => void;
  updateAlertStage: (id: string, service: ResponseService, stage: AlertStage) => void;
  upsertWilayaNumbers: (entry: Omit<WilayaNumbers, 'id'>, id?: string) => void;
  deleteWilayaNumbers: (id: string) => void;
  toggleUserDisabled: (username: string) => void;
  captureLocation: () => Promise<boolean>;
  clearLocationError: () => void;
}

const STORAGE_KEY = 'solvex-alert-demo-v1';
const DEFAULT_DATA: AppData = {
  profile: null,
  knownUsers: [],
  disabledUsers: [],
  role: 'user',
  language: 'fr',
  vehicleType: 'car',
  wilaya: 'Alger',
  testMode: true,
  deviceConnected: false,
  contacts: [],
  alerts: [],
  wilayaNumbers: [],
  currentLocation: null,
};

const AppContext = createContext<AppContextValue | null>(null);

function makeId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

function normalize(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase();
}

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [data, setData] = useState<AppData>(DEFAULT_DATA);
  const [ready, setReady] = useState(false);
  const [storageError, setStorageError] = useState(false);
  const [locationError, setLocationError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    AsyncStorage.getItem(STORAGE_KEY)
      .then((raw) => {
        if (!mounted) return;
        if (raw) {
          const parsed = JSON.parse(raw) as Partial<AppData>;
          setData({
            ...DEFAULT_DATA,
            ...parsed,
            alerts: (parsed.alerts ?? []).map((alert) => ({
              ...alert,
              serviceStatus: alert.serviceStatus ?? {
                police: alert.stage,
                civilProtection: alert.stage,
              },
              serviceStatusTimestamps: alert.serviceStatusTimestamps ?? {
                police: { ...alert.responseTimestamps },
                civilProtection: { ...alert.responseTimestamps },
              },
            })),
          });
        }
      })
      .catch(() => {
        if (mounted) setStorageError(true);
      })
      .finally(() => {
        if (mounted) setReady(true);
      });
    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (!ready) return;
    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data)).catch(() => {
      setStorageError(true);
    });
  }, [data, ready]);

  const patchData = useCallback((patch: Partial<AppData>) => {
    setData((current) => ({ ...current, ...patch }));
  }, []);

  const createProfile = useCallback((profile: Omit<Profile, 'role'>) => {
    const nextProfile: Profile = { ...profile, role: 'user', createdAt: new Date().toISOString() };
    setData((current) => ({
      ...current,
      profile: nextProfile,
      role: 'user',
      wilaya: nextProfile.wilaya,
      knownUsers: [
        ...current.knownUsers.filter(
          (user) => user.username.toLowerCase() !== nextProfile.username.toLowerCase(),
        ),
        nextProfile,
      ],
    }));
  }, []);

  const startDemo = useCallback((role: Role, username = '') => {
    const normalizedUsername = username.trim() || (role === 'admin' ? 'admin-demo' : 'demo-user');
    if (
      role === 'user' &&
      data.disabledUsers.includes(normalizedUsername.toLowerCase())
    ) {
      return false;
    }
    setData((current) => {
      const existing = current.knownUsers.find(
        (user) => user.username.toLowerCase() === normalizedUsername.toLowerCase(),
      );
      const profile: Profile =
        role === 'admin'
          ? {
              fullName: 'Admin — aperçu',
              username: normalizedUsername,
              phone: '',
              wilaya: current.wilaya,
              role,
            }
          : existing ?? {
              fullName: normalizedUsername,
              username: normalizedUsername,
              phone: '',
              wilaya: current.wilaya,
              role,
              createdAt: new Date().toISOString(),
            };
      return {
        ...current,
        profile,
        role,
        knownUsers:
          role === 'user' && !existing
            ? [...current.knownUsers, profile]
            : current.knownUsers,
      };
    });
    return true;
  }, [data.disabledUsers]);

  const signOut = useCallback(() => {
    setData((current) => ({ ...current, profile: null, role: 'user', deviceConnected: false }));
  }, []);

  const patchProfile = useCallback(
    (patch: Partial<Pick<Profile, 'fullName' | 'phone' | 'wilaya'>>) => {
      setData((current) => {
        if (!current.profile) return current;
        const profile = { ...current.profile, ...patch };
        return {
          ...current,
          profile,
          wilaya: patch.wilaya ?? current.wilaya,
          knownUsers: current.knownUsers.map((user) =>
            user.username === profile.username ? profile : user,
          ),
        };
      });
    },
    [],
  );

  const addContact = useCallback((contact: Omit<EmergencyContact, 'id'>) => {
    setData((current) => ({
      ...current,
      contacts: [...current.contacts, { ...contact, id: makeId() }],
    }));
  }, []);

  const updateContact = useCallback((contact: EmergencyContact) => {
    setData((current) => ({
      ...current,
      contacts: current.contacts.map((item) => (item.id === contact.id ? contact : item)),
    }));
  }, []);

  const deleteContact = useCallback((id: string) => {
    setData((current) => ({
      ...current,
      contacts: current.contacts.filter((item) => item.id !== id),
    }));
  }, []);

  const addTestAlert = useCallback(() => {
    setData((current) => {
      const alert: AlertRecord = {
        id: makeId(),
        createdAt: new Date().toISOString(),
        latitude: current.currentLocation?.latitude ?? null,
        longitude: current.currentLocation?.longitude ?? null,
        wilaya: current.wilaya,
        vehicleType: current.vehicleType,
        stage: 'Test recorded',
        responseTimestamps: { 'Test recorded': new Date().toISOString() },
        serviceStatus: {
          police: 'Test recorded',
          civilProtection: 'Test recorded',
        },
        serviceStatusTimestamps: {
          police: { 'Test recorded': new Date().toISOString() },
          civilProtection: { 'Test recorded': new Date().toISOString() },
        },
      };
      return { ...current, alerts: [alert, ...current.alerts] };
    });
  }, []);

  const updateAlertStage = useCallback((id: string, service: ResponseService, stage: AlertStage) => {
    setData((current) => ({
      ...current,
      alerts: current.alerts.map((alert) =>
        alert.id !== id
          ? alert
          : (() => {
              const now = new Date().toISOString();
              const serviceStatus = alert.serviceStatus ?? {
                police: alert.stage,
                civilProtection: alert.stage,
              };
              const serviceStatusTimestamps = alert.serviceStatusTimestamps ?? {
                police: { ...alert.responseTimestamps },
                civilProtection: { ...alert.responseTimestamps },
              };
              const nextServiceStatus = { ...serviceStatus, [service]: stage };
              const order: AlertStage[] = [
                'Test recorded',
                'Test received',
                'Test team dispatched',
                'Test arrived',
                'Test resolved',
              ];
              const overall = Object.values(nextServiceStatus).reduce(
                (latest, value) => (order.indexOf(value) > order.indexOf(latest) ? value : latest),
                'Test recorded' as AlertStage,
              );
              return {
                ...alert,
                stage: overall,
                serviceStatus: nextServiceStatus,
                serviceStatusTimestamps: {
                  ...serviceStatusTimestamps,
                  [service]: {
                    ...serviceStatusTimestamps[service],
                    [stage]: now,
                  },
                },
                responseTimestamps: { ...alert.responseTimestamps, [stage]: now },
              };
            })(),
      ),
    }));
  }, []);

  const upsertWilayaNumbers = useCallback(
    (entry: Omit<WilayaNumbers, 'id'>, id?: string) => {
      setData((current) => {
        if (id) {
          return {
            ...current,
            wilayaNumbers: current.wilayaNumbers.map((item) =>
              item.id === id ? { ...item, ...entry } : item,
            ),
          };
        }
        const existing = current.wilayaNumbers.find((item) => item.wilaya === entry.wilaya);
        if (existing) {
          return {
            ...current,
            wilayaNumbers: current.wilayaNumbers.map((item) =>
              item.id === existing.id ? { ...item, ...entry } : item,
            ),
          };
        }
        return { ...current, wilayaNumbers: [...current.wilayaNumbers, { ...entry, id: makeId() }] };
      });
    },
    [],
  );

  const deleteWilayaNumbers = useCallback((id: string) => {
    setData((current) => ({
      ...current,
      wilayaNumbers: current.wilayaNumbers.filter((item) => item.id !== id),
    }));
  }, []);

  const toggleUserDisabled = useCallback((username: string) => {
    const key = username.toLowerCase();
    setData((current) => ({
      ...current,
      disabledUsers: current.disabledUsers.includes(key)
        ? current.disabledUsers.filter((item) => item !== key)
        : [...current.disabledUsers, key],
    }));
  }, []);

  const captureLocation = useCallback(async () => {
    setLocationError(null);
    try {
      const permission = await Location.requestForegroundPermissionsAsync();
      if (!permission.granted) {
        setLocationError(
          permission.canAskAgain
            ? 'Autorisez la position pour l’ajouter à un test.'
            : 'Position refusée. Activez-la dans les réglages du téléphone.',
        );
        return false;
      }
      const position = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      });
      const currentLocation = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      };
      const places = await Location.reverseGeocodeAsync(currentLocation);
      const placeName = places[0]?.region ?? places[0]?.subregion ?? places[0]?.city ?? '';
      const matchedWilaya = WILAYAS_FR.find(
        (wilaya) => normalize(wilaya) === normalize(placeName),
      );
      setData((current) => ({
        ...current,
        currentLocation,
        ...(matchedWilaya ? { wilaya: matchedWilaya } : {}),
        ...(matchedWilaya && current.profile
          ? {
              profile: { ...current.profile, wilaya: matchedWilaya },
              knownUsers: current.knownUsers.map((user) =>
                user.username === current.profile?.username
                  ? { ...user, wilaya: matchedWilaya }
                  : user,
              ),
            }
          : {}),
      }));
      return true;
    } catch {
      setLocationError('Impossible d’obtenir la position. Réessayez ou choisissez la wilaya.');
      return false;
    }
  }, []);

  const value = useMemo<AppContextValue>(
    () => ({
      data,
      ready,
      storageError,
      locationError,
      createProfile,
      startDemo,
      signOut,
      patchProfile,
      patchData,
      addContact,
      updateContact,
      deleteContact,
      addTestAlert,
      updateAlertStage,
      upsertWilayaNumbers,
      deleteWilayaNumbers,
      toggleUserDisabled,
      captureLocation,
      clearLocationError: () => setLocationError(null),
    }),
    [
      data,
      ready,
      storageError,
      locationError,
      createProfile,
      startDemo,
      signOut,
      patchProfile,
      patchData,
      addContact,
      updateContact,
      deleteContact,
      addTestAlert,
      updateAlertStage,
      upsertWilayaNumbers,
      deleteWilayaNumbers,
      toggleUserDisabled,
      captureLocation,
    ],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp(): AppContextValue {
  const value = useContext(AppContext);
  if (!value) throw new Error('useApp must be used inside AppProvider.');
  return value;
}
