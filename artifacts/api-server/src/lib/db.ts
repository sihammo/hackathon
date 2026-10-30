import mongoose from "mongoose";
import { logger } from "./logger";
import {
  UserModel,
  DeviceModel,
  AlertModel,
  HotspotModel,
  InsurancePartnerModel,
  EmergencyContactModel,
  WilayaModel,
} from "../models";

let isConnected = false;

export async function connectMongo(): Promise<boolean> {
  const uri = process.env.MONGODB_URI;

  if (!uri) {
    logger.warn(
      "MONGODB_URI environment variable is not set. Running in local resilient mode with seeded memory storage."
    );
    return false;
  }

  try {
    logger.info("Connecting to MongoDB...");
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 5000,
    });
    isConnected = true;
    logger.info("MongoDB connected successfully");
    await seedDatabase();
    return true;
  } catch (err) {
    logger.error({ err }, "Failed to connect to MongoDB; running in fallback mode");
    isConnected = false;
    return false;
  }
}

export function isMongoConnected(): boolean {
  return isConnected && mongoose.connection.readyState === 1;
}

// ---------------------------------------------------------------------------
// All Pre-seeded Accounts & Initial Data ("Ga3 account mtnsa walo")
// ---------------------------------------------------------------------------

export const SEED_USERS = [
  // Admin Account
  {
    uid: "demo-admin-1",
    fullName: "Directeur Général Slamtek",
    username: "admin",
    password: "admin123",
    phone: "0550000000",
    wilayaCode: 16,
    role: "admin" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: true,
    testPhoneNumber: "0555999888",
    avatarUrl: "/assets/images/karim.jpg",
    insuranceCompany: "CAAT",
    policyNumber: "ADM-2026-001",
  },
  // Karim Benali (Primary User)
  {
    uid: "demo-user-1",
    fullName: "Karim Benali",
    username: "karim",
    password: "karim123",
    phone: "0555123456",
    wilayaCode: 16,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: true,
    testPhoneNumber: "0555999888",
    avatarUrl: "/assets/images/karim.jpg",
    insuranceCompany: "CAAT",
    policyNumber: "POL-16-982341",
  },
  // Samir Mansour (Motorcycle Driver - Oran)
  {
    uid: "u2",
    fullName: "Samir Mansour",
    username: "samir",
    password: "samir123",
    phone: "0770334455",
    wilayaCode: 31,
    role: "user" as const,
    disabled: false,
    vehicleType: "motorcycle" as const,
    testMode: false,
    testPhoneNumber: "0770334455",
    avatarUrl: "/assets/assets/images/driver_moto.jpg",
    insuranceCompany: "SAA",
    policyNumber: "POL-31-441199",
  },
  // Nadia Khelifi (Blida)
  {
    uid: "u3",
    fullName: "Nadia Khelifi",
    username: "nadia",
    password: "nadia123",
    phone: "0661556677",
    wilayaCode: 9,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "0661556677",
    avatarUrl: "/assets/assets/images/driver_woman.jpg",
    insuranceCompany: "CIAR",
    policyNumber: "POL-09-556677",
  },
  // Mohamed Larbi (Constantine)
  {
    uid: "u4",
    fullName: "Mohamed Larbi",
    username: "mohamed_l",
    password: "mohamed123",
    phone: "0550112233",
    wilayaCode: 25,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "0550112233",
    avatarUrl: "/assets/assets/images/driver_casual.jpg",
    insuranceCompany: "CASH",
    policyNumber: "POL-25-112233",
  },
  // Amina Zerrouki (Sétif)
  {
    uid: "u5",
    fullName: "Amina Zerrouki",
    username: "amina_z",
    password: "amina123",
    phone: "0662334455",
    wilayaCode: 19,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "0662334455",
    avatarUrl: "/assets/assets/images/driver_woman.jpg",
    insuranceCompany: "Macir Vie",
    policyNumber: "POL-19-223344",
  },
  // Yacine Mansouri (Oran)
  {
    uid: "u6",
    fullName: "Yacine Mansouri",
    username: "yacine_m",
    password: "yacine123",
    phone: "0771889900",
    wilayaCode: 31,
    role: "user" as const,
    disabled: false,
    vehicleType: "motorcycle" as const,
    testMode: false,
    testPhoneNumber: "0771889900",
    insuranceCompany: "SAA",
  },
  // Dr. Meriem Saidi (Constantine)
  {
    uid: "u7",
    fullName: "Dr. Meriem Saidi",
    username: "meriem_s",
    password: "meriem123",
    phone: "0555443322",
    wilayaCode: 25,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "0555443322",
    insuranceCompany: "CAAT",
  },
  // Sofiane Bouzid (Sétif)
  {
    uid: "u8",
    fullName: "Sofiane Bouzid",
    username: "sofiane_b",
    password: "sofiane123",
    phone: "0663778899",
    wilayaCode: 19,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "0663778899",
    insuranceCompany: "CIAR",
  },
  // Bilal Haddad (Blida)
  {
    uid: "u9",
    fullName: "Bilal Haddad",
    username: "bilal_h",
    password: "bilal123",
    phone: "0772112233",
    wilayaCode: 9,
    role: "user" as const,
    disabled: false,
    vehicleType: "motorcycle" as const,
    testMode: false,
    testPhoneNumber: "0772112233",
    insuranceCompany: "Trust",
  },
  // Ryad Belkacem (Annaba)
  {
    uid: "u10",
    fullName: "Ryad Belkacem",
    username: "ryad_b",
    password: "ryad123",
    phone: "0551998877",
    wilayaCode: 23,
    role: "user" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "0551998877",
    insuranceCompany: "CAAT",
  },
  // Emergency Authorities Accounts
  {
    uid: "auth-civil-protection",
    fullName: "Protection Civile Algérienne (Centre Opérationnel)",
    username: "protection_civile",
    password: "protection123",
    phone: "14",
    wilayaCode: 16,
    role: "civil_protection" as const,
    disabled: false,
    vehicleType: "truck" as const,
    testMode: false,
    testPhoneNumber: "14",
    insuranceCompany: "État",
  },
  {
    uid: "auth-police",
    fullName: "DGSN - Sûreté Nationale (Direction Générale)",
    username: "police_nationale",
    password: "police123",
    phone: "17",
    wilayaCode: 16,
    role: "police" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "17",
    insuranceCompany: "État",
  },
  // Insurance Companies Accounts
  {
    uid: "ins-caat",
    fullName: "CAAT Assurances (Direction des Sinistres)",
    username: "assurance_caat",
    password: "caat123",
    phone: "021000100",
    wilayaCode: 16,
    role: "insurance" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "021000100",
    insuranceCompany: "CAAT",
  },
  {
    uid: "ins-saa",
    fullName: "SAA Assurances (Société Nationale d'Assurance)",
    username: "assurance_saa",
    password: "saa123",
    phone: "021000200",
    wilayaCode: 16,
    role: "insurance" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "021000200",
    insuranceCompany: "SAA",
  },
  {
    uid: "ins-ciar",
    fullName: "CIAR - Compagnie Internationale d'Assurance",
    username: "assurance_ciar",
    password: "ciar123",
    phone: "021000300",
    wilayaCode: 16,
    role: "insurance" as const,
    disabled: false,
    vehicleType: "car" as const,
    testMode: false,
    testPhoneNumber: "021000300",
    insuranceCompany: "CIAR",
  },
];

export const SEED_DEVICES = [
  {
    id: "SOLVEX-A101",
    userId: "demo-user-1",
    name: "Slamtek ESP32-Box #101",
    vehicleType: "car" as const,
    connected: true,
    batteryLevel: 98,
    signalStrength: -68,
    firmwareVersion: "v2.1.0-esp32",
    lastSeen: new Date(),
    registeredAt: new Date(Date.now() - 15 * 86400000),
  },
  {
    id: "SOLVEX-M102",
    userId: "u2",
    name: "Slamtek Moto-Box #102",
    vehicleType: "motorcycle" as const,
    connected: true,
    batteryLevel: 92,
    signalStrength: -72,
    firmwareVersion: "v2.1.0-esp32",
    lastSeen: new Date(),
    registeredAt: new Date(Date.now() - 10 * 86400000),
  },
  {
    id: "SOLVEX-A103",
    userId: "u3",
    name: "Slamtek Auto-Box #103",
    vehicleType: "car" as const,
    connected: false,
    batteryLevel: 84,
    signalStrength: -80,
    firmwareVersion: "v2.1.0-esp32",
    lastSeen: new Date(Date.now() - 3600000),
    registeredAt: new Date(Date.now() - 20 * 86400000),
  },
  {
    id: "SOLVEX-A104",
    userId: "u4",
    name: "Slamtek Auto-Box #104",
    vehicleType: "car" as const,
    connected: true,
    batteryLevel: 99,
    signalStrength: -65,
    firmwareVersion: "v2.1.0-esp32",
    lastSeen: new Date(),
    registeredAt: new Date(Date.now() - 8 * 86400000),
  },
];

export const SEED_CONTACTS = [
  {
    id: "c1",
    userId: "demo-user-1",
    name: "Yacine Benali",
    phone: "0551223344",
    relation: "Frère",
  },
  {
    id: "c2",
    userId: "demo-user-1",
    name: "Amina Benali",
    phone: "0661998877",
    relation: "Mère",
  },
  {
    id: "c3",
    userId: "u2",
    name: "Houari Mansour",
    phone: "0771990011",
    relation: "Père",
  },
];

export const SEED_HOTSPOTS = [
  {
    id: "hp-chiffa",
    title: "Gorges de Chiffa (RN1) - Blida",
    description: "Virages dangereux, brouillard fréquent et risque de glissade sur la chaussée.",
    lat: 36.4251,
    lng: 2.7654,
    wilayaCode: 9,
    radius: 400,
    severity: "high" as const,
    accidentsCount: 47,
  },
  {
    id: "hp-djebahia",
    title: "Descente de Djebahia (Autoroute Est-Ouest) - Bouira",
    description: "Pente abrupte de 6 km très dangereuse pour les poids lourds et véhicules légers.",
    lat: 36.5123,
    lng: 3.7541,
    wilayaCode: 10,
    radius: 600,
    severity: "high" as const,
    accidentsCount: 68,
  },
  {
    id: "hp-kouba",
    title: "Échangeur Oued Ouchayah / Rocade Sud - Alger",
    description: "Fort ralentissement imprévu, intersections multiples et vitesse élevée.",
    lat: 36.7214,
    lng: 3.0821,
    wilayaCode: 16,
    radius: 350,
    severity: "medium" as const,
    accidentsCount: 32,
  },
  {
    id: "hp-corniche-oran",
    title: "Corniche Oranaise (Mers El Kébir) - Oran",
    description: "Route sinueuse en bord de mer, risque de chute et manque de visibilité nocturne.",
    lat: 35.7312,
    lng: -0.6891,
    wilayaCode: 31,
    radius: 450,
    severity: "high" as const,
    accidentsCount: 39,
  },
  {
    id: "hp-constantine",
    title: "Descente du Pont Géant / El Kantara - Constantine",
    description: "Pente forte et verglas en hiver.",
    lat: 36.3654,
    lng: 6.6147,
    wilayaCode: 25,
    radius: 300,
    severity: "medium" as const,
    accidentsCount: 28,
  },
];

export const SEED_INSURANCE_PARTNERS = [
  {
    code: "caat",
    name: "CAAT Assurances",
    fullNameAr: "الشركة الجزائرية للتأمينات",
    commercialPlan: "Formule Tout Risque + Boîtier Slamtek Inclus",
    discountPercentage: 25,
    contactEmail: "slamtek@caat.dz",
    contactPhone: "021000100",
    activePolicies: 1840,
    claimsProcessed: 42,
  },
  {
    code: "saa",
    name: "SAA Assurances",
    fullNameAr: "الشركة الوطنية للتأمين",
    commercialPlan: "Pack Sécurité Routière & Détection Rapide",
    discountPercentage: 20,
    contactEmail: "partenariat@saa.dz",
    contactPhone: "021000200",
    activePolicies: 2450,
    claimsProcessed: 67,
  },
  {
    code: "ciar",
    name: "CIAR Assurances",
    fullNameAr: "الشركة الدولية للتأمين وإعادة التأمين",
    commercialPlan: "Contrat Connecté Assistance 24/7",
    discountPercentage: 18,
    contactEmail: "contact@ciar.dz",
    contactPhone: "021000300",
    activePolicies: 920,
    claimsProcessed: 19,
  },
  {
    code: "cash",
    name: "CASH Assurances",
    fullNameAr: "شركة التأمين للمحروقات",
    commercialPlan: "Flottes Entreprises & Particuliers",
    discountPercentage: 22,
    contactEmail: "flottes@cash-assurances.dz",
    contactPhone: "021000400",
    activePolicies: 630,
    claimsProcessed: 14,
  },
  {
    code: "macir_vie",
    name: "Macir Vie",
    fullNameAr: "ماصير في للتأمين",
    commercialPlan: "Assurance Conducteur & Passagers",
    discountPercentage: 15,
    contactEmail: "info@macirvie.com",
    contactPhone: "021000500",
    activePolicies: 410,
    claimsProcessed: 8,
  },
];

export const SEED_ALERTS = [
  {
    id: "a1",
    userId: "demo-user-1",
    userName: "Karim Benali",
    userPhone: "0555123456",
    deviceId: "SOLVEX-A101",
    lat: 36.7538,
    lng: 3.0588,
    wilayaCode: 16,
    vehicleType: "car" as const,
    status: "arrived" as const,
    trigger: "impact" as const,
    peakG: 4.8,
    tilt: 14.5,
    statusTimestamps: {
      sent: new Date(Date.now() - 45 * 60000),
      received: new Date(Date.now() - 42 * 60000),
      dispatched: new Date(Date.now() - 38 * 60000),
      arrived: new Date(Date.now() - 25 * 60000),
    },
    responses: {
      police: {
        status: "arrived",
        timestamps: { arrived: new Date(Date.now() - 25 * 60000) },
      },
      civilProtection: {
        status: "arrived",
        timestamps: { arrived: new Date(Date.now() - 28 * 60000) },
      },
    },
    notifiedNumbers: ["0551223344", "0661998877"],
    testMode: true,
  },
  {
    id: "a2",
    userId: "u2",
    userName: "Samir Mansour",
    userPhone: "0770334455",
    deviceId: "SOLVEX-M102",
    lat: 35.6987,
    lng: -0.6349,
    wilayaCode: 31,
    vehicleType: "motorcycle" as const,
    status: "dispatched" as const,
    trigger: "fall" as const,
    peakG: 3.5,
    tilt: 72.0,
    statusTimestamps: {
      sent: new Date(Date.now() - 135 * 60000),
      received: new Date(Date.now() - 130 * 60000),
      dispatched: new Date(Date.now() - 122 * 60000),
    },
    responses: {
      civilProtection: {
        status: "dispatched",
        timestamps: { dispatched: new Date(Date.now() - 122 * 60000) },
      },
    },
    notifiedNumbers: ["0770334455", "0771990011"],
    testMode: true,
  },
];

export async function seedDatabase() {
  if (!isMongoConnected()) {
    logger.info("MongoDB not connected; using local persistent store.");
    return;
  }

  try {
    logger.info("Seeding MongoDB with all Algerian accounts, devices, and hotspots...");

    // Seed Users
    for (const u of SEED_USERS) {
      await UserModel.findOneAndUpdate({ uid: u.uid }, u, {
        upsert: true,
        new: true,
      });
    }

    // Seed Devices
    for (const d of SEED_DEVICES) {
      await DeviceModel.findOneAndUpdate({ id: d.id }, d, {
        upsert: true,
        new: true,
      });
    }

    // Seed Emergency Contacts
    for (const c of SEED_CONTACTS) {
      await EmergencyContactModel.findOneAndUpdate({ id: c.id }, c, {
        upsert: true,
        new: true,
      });
    }

    // Seed Hotspots
    for (const h of SEED_HOTSPOTS) {
      await HotspotModel.findOneAndUpdate({ id: h.id }, h, {
        upsert: true,
        new: true,
      });
    }

    // Seed Insurance Partners
    for (const p of SEED_INSURANCE_PARTNERS) {
      await InsurancePartnerModel.findOneAndUpdate({ code: p.code }, p, {
        upsert: true,
        new: true,
      });
    }

    // Seed Alerts
    for (const a of SEED_ALERTS) {
      await AlertModel.findOneAndUpdate({ id: a.id }, a, {
        upsert: true,
        new: true,
      });
    }

    logger.info("All accounts, devices, hotspots, and insurance models successfully seeded into MongoDB!");
  } catch (err) {
    logger.error({ err }, "Error during MongoDB seed");
  }
}
