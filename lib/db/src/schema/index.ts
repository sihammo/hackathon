import { pgTable, text, integer, boolean, doublePrecision, timestamp, jsonb } from "drizzle-orm/pg-core";

// ---------------------------------------------------------------------------
// Users Table (All Accounts)
// ---------------------------------------------------------------------------
export const usersTable = pgTable("users", {
  uid: text("uid").primaryKey(),
  fullName: text("full_name").notNull(),
  username: text("username").notNull().unique(),
  password: text("password").notNull().default("slamtek123"),
  phone: text("phone").notNull(),
  wilayaCode: integer("wilaya_code").notNull().default(16),
  role: text("role").notNull().default("user"), // 'admin' | 'user' | 'insurance' | 'police' | 'civil_protection'
  disabled: boolean("disabled").notNull().default(false),
  vehicleType: text("vehicle_type").notNull().default("car"), // 'car' | 'motorcycle' | 'truck'
  testMode: boolean("test_mode").notNull().default(true),
  testPhoneNumber: text("test_phone_number").notNull().default("0555999888"),
  avatarUrl: text("avatar_url"),
  insuranceCompany: text("insurance_company").default("CAAT"),
  policyNumber: text("policy_number"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export type User = typeof usersTable.$inferSelect;
export type InsertUser = typeof usersTable.$inferInsert;

// ---------------------------------------------------------------------------
// Devices Table (IoT ESP32 Hardware Units)
// ---------------------------------------------------------------------------
export const devicesTable = pgTable("devices", {
  id: text("id").primaryKey(), // e.g. SOLVEX-A101
  userId: text("user_id").notNull(),
  name: text("name").notNull(),
  vehicleType: text("vehicle_type").notNull().default("car"),
  connected: boolean("connected").notNull().default(false),
  batteryLevel: integer("battery_level").notNull().default(100),
  signalStrength: integer("signal_strength").notNull().default(-70),
  firmwareVersion: text("firmware_version").notNull().default("v2.1.0-esp32"),
  lastSeen: timestamp("last_seen", { withTimezone: true }).defaultNow(),
  registeredAt: timestamp("registered_at", { withTimezone: true }).defaultNow(),
});

export type Device = typeof devicesTable.$inferSelect;
export type InsertDevice = typeof devicesTable.$inferInsert;

// ---------------------------------------------------------------------------
// Alerts Table (Accidents & Crash Detections)
// ---------------------------------------------------------------------------
export const alertsTable = pgTable("alerts", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull(),
  userName: text("user_name").notNull(),
  userPhone: text("user_phone").notNull(),
  deviceId: text("device_id").notNull(),
  lat: doublePrecision("lat").notNull(),
  lng: doublePrecision("lng").notNull(),
  wilayaCode: integer("wilaya_code").notNull(),
  vehicleType: text("vehicle_type").notNull().default("car"),
  status: text("status").notNull().default("sent"), // 'sent' | 'received' | 'dispatched' | 'arrived' | 'resolved'
  trigger: text("trigger").notNull().default("impact"), // 'impact' | 'fall' | 'rollover' | 'manual'
  peakG: doublePrecision("peak_g").notNull().default(0),
  tilt: doublePrecision("tilt").notNull().default(0),
  statusTimestamps: jsonb("status_timestamps").default({}),
  responses: jsonb("responses").default({}),
  notifiedNumbers: jsonb("notified_numbers").default([]),
  testMode: boolean("test_mode").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export type Alert = typeof alertsTable.$inferSelect;
export type InsertAlert = typeof alertsTable.$inferInsert;

// ---------------------------------------------------------------------------
// Hotspots Table (Points Noirs Routiers Algérie)
// ---------------------------------------------------------------------------
export const hotspotsTable = pgTable("hotspots", {
  id: text("id").primaryKey(),
  title: text("title").notNull(),
  description: text("description").default(""),
  lat: doublePrecision("lat").notNull(),
  lng: doublePrecision("lng").notNull(),
  wilayaCode: integer("wilaya_code").notNull(),
  radius: integer("radius").notNull().default(300),
  severity: text("severity").notNull().default("high"), // 'high' | 'medium' | 'low'
  accidentsCount: integer("accidents_count").notNull().default(0),
});

export type Hotspot = typeof hotspotsTable.$inferSelect;
export type InsertHotspot = typeof hotspotsTable.$inferInsert;

// ---------------------------------------------------------------------------
// Insurance Partners Table (Les Assurances CAAT, SAA, CIAR, CASH, Macir)
// ---------------------------------------------------------------------------
export const insurancePartnersTable = pgTable("insurance_partners", {
  code: text("code").primaryKey(),
  name: text("name").notNull(),
  fullNameAr: text("full_name_ar").default(""),
  commercialPlan: text("commercial_plan").notNull(),
  discountPercentage: integer("discount_percentage").notNull().default(20),
  contactEmail: text("contact_email").default(""),
  contactPhone: text("contact_phone").default(""),
  activePolicies: integer("active_policies").notNull().default(0),
  claimsProcessed: integer("claims_processed").notNull().default(0),
});

export type InsurancePartner = typeof insurancePartnersTable.$inferSelect;
export type InsertInsurancePartner = typeof insurancePartnersTable.$inferInsert;

// ---------------------------------------------------------------------------
// Emergency Contacts Table
// ---------------------------------------------------------------------------
export const emergencyContactsTable = pgTable("emergency_contacts", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull(),
  name: text("name").notNull(),
  phone: text("phone").notNull(),
  relation: text("relation").notNull().default("Proche"),
});

export type EmergencyContact = typeof emergencyContactsTable.$inferSelect;
export type InsertEmergencyContact = typeof emergencyContactsTable.$inferInsert;

// ---------------------------------------------------------------------------
// Wilayas Emergency Table (58 Wilayas)
// ---------------------------------------------------------------------------
export const wilayasTable = pgTable("wilayas", {
  code: integer("code").primaryKey(),
  name: text("name").notNull(),
  nameAr: text("name_ar").default(""),
  police: text("police").notNull().default("17"),
  civilProtection: text("civil_protection").notNull().default("14"),
  gendarmerie: text("gendarmerie").notNull().default("1055"),
});

export type Wilaya = typeof wilayasTable.$inferSelect;
export type InsertWilaya = typeof wilayasTable.$inferInsert;