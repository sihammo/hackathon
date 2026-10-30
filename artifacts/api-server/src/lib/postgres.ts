import { pool as pgPool } from "@workspace/db";
import { logger } from "./logger";

export { pgPool };

let pgConnected = false;

// Check connection on startup
export async function testPgConnection(): Promise<boolean> {
  try {
    const res = await pgPool.query("SELECT NOW() as current_time, COUNT(*) as users_count FROM users;");
    pgConnected = true;
    logger.info(
      {
        time: (res.rows[0] as any)?.current_time,
        usersCount: (res.rows[0] as any)?.users_count,
        host: "aws-1-eu-west-3.pooler.supabase.com",
      },
      "Supabase PostgreSQL connected successfully!"
    );
    return true;
  } catch (err: any) {
    logger.warn({ error: err.message }, "Supabase PostgreSQL initial check deferred");
    pgConnected = false;
    return false;
  }
}

export function isPgConnected(): boolean {
  return pgConnected;
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------
export async function getPgUserByLogin(login: string) {
  const clean = login.trim().toLowerCase();
  const res = await pgPool.query(
    `SELECT uid, full_name, username, password, phone, wilaya_code, role, disabled, vehicle_type, test_mode, test_phone_number, avatar_url, insurance_company, policy_number, created_at
     FROM users
     WHERE LOWER(username) = $1 OR phone = $2
     LIMIT 1;`,
    [clean, login.trim()]
  );
  if (res.rows.length === 0) return null;
  const row: any = res.rows[0];
  return {
    uid: row.uid,
    fullName: row.full_name,
    username: row.username,
    password: row.password,
    phone: row.phone,
    wilayaCode: row.wilaya_code,
    role: row.role,
    disabled: row.disabled,
    vehicleType: row.vehicle_type,
    testMode: row.test_mode,
    testPhoneNumber: row.test_phone_number,
    avatarUrl: row.avatar_url,
    insuranceCompany: row.insurance_company,
    policyNumber: row.policy_number,
    createdAt: row.created_at,
  };
}

export async function getPgUserByUid(uid: string) {
  const res = await pgPool.query(
    `SELECT uid, full_name, username, phone, wilaya_code, role, disabled, vehicle_type, test_mode, test_phone_number, avatar_url, insurance_company, policy_number, created_at
     FROM users
     WHERE uid = $1
     LIMIT 1;`,
    [uid]
  );
  if (res.rows.length === 0) return null;
  const row: any = res.rows[0];
  return {
    uid: row.uid,
    fullName: row.full_name,
    username: row.username,
    phone: row.phone,
    wilayaCode: row.wilaya_code,
    role: row.role,
    disabled: row.disabled,
    vehicleType: row.vehicle_type,
    testMode: row.test_mode,
    testPhoneNumber: row.test_phone_number,
    avatarUrl: row.avatar_url,
    insuranceCompany: row.insurance_company,
    policyNumber: row.policy_number,
    createdAt: row.created_at,
  };
}

export async function getAllPgUsers(role?: string, wilaya?: number) {
  let query = `SELECT uid, full_name, username, phone, wilaya_code, role, disabled, vehicle_type, test_mode, test_phone_number, avatar_url, insurance_company, policy_number, created_at FROM users WHERE 1=1`;
  const params: any[] = [];

  if (role) {
    params.push(role);
    query += ` AND role = $${params.length}`;
  }
  if (wilaya) {
    params.push(wilaya);
    query += ` AND wilaya_code = $${params.length}`;
  }
  query += ` ORDER BY created_at DESC;`;

  const res = await pgPool.query(query, params);
  return res.rows.map((row: any) => ({
    uid: row.uid,
    fullName: row.full_name,
    username: row.username,
    phone: row.phone,
    wilayaCode: row.wilaya_code,
    role: row.role,
    disabled: row.disabled,
    vehicleType: row.vehicle_type,
    testMode: row.test_mode,
    testPhoneNumber: row.test_phone_number,
    avatarUrl: row.avatar_url,
    insuranceCompany: row.insurance_company,
    policyNumber: row.policy_number,
    createdAt: row.created_at,
  }));
}

// ---------------------------------------------------------------------------
// Devices
// ---------------------------------------------------------------------------
export async function getPgDevices(userId?: string) {
  let query = `SELECT * FROM devices WHERE 1=1`;
  const params: any[] = [];
  if (userId) {
    params.push(userId);
    query += ` AND user_id = $${params.length}`;
  }
  query += ` ORDER BY last_seen DESC;`;
  const res = await pgPool.query(query, params);
  return res.rows.map((r: any) => ({
    id: r.id,
    userId: r.user_id,
    name: r.name,
    vehicleType: r.vehicle_type,
    connected: r.connected,
    batteryLevel: r.battery_level,
    signalStrength: r.signal_strength,
    firmwareVersion: r.firmware_version,
    lastSeen: r.last_seen,
    registeredAt: r.registered_at,
  }));
}

export async function updatePgDeviceTelemetry(id: string, batteryLevel?: number, signalStrength?: number, connected?: boolean) {
  const res = await pgPool.query(
    `UPDATE devices
     SET battery_level = COALESCE($2, battery_level),
         signal_strength = COALESCE($3, signal_strength),
         connected = COALESCE($4, connected),
         last_seen = NOW()
     WHERE id = $1
     RETURNING *;`,
    [id, batteryLevel, signalStrength, connected]
  );
  return res.rows[0];
}

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------
export async function getPgAlerts(userId?: string, wilayaCode?: number, status?: string) {
  let query = `SELECT * FROM alerts WHERE 1=1`;
  const params: any[] = [];
  if (userId) {
    params.push(userId);
    query += ` AND user_id = $${params.length}`;
  }
  if (wilayaCode) {
    params.push(wilayaCode);
    query += ` AND wilaya_code = $${params.length}`;
  }
  if (status) {
    params.push(status);
    query += ` AND status = $${params.length}`;
  }
  query += ` ORDER BY created_at DESC;`;

  const res = await pgPool.query(query, params);
  return res.rows.map((r: any) => ({
    id: r.id,
    userId: r.user_id,
    userName: r.user_name,
    userPhone: r.user_phone,
    deviceId: r.device_id,
    lat: r.lat,
    lng: r.lng,
    wilayaCode: r.wilaya_code,
    vehicleType: r.vehicle_type,
    status: r.status,
    trigger: r.trigger,
    peakG: r.peak_g,
    tilt: r.tilt,
    statusTimestamps: r.status_timestamps,
    responses: r.responses,
    notifiedNumbers: r.notified_numbers,
    testMode: r.test_mode,
    createdAt: r.created_at,
  }));
}

export async function createPgAlert(alert: any) {
  const res = await pgPool.query(
    `INSERT INTO alerts (id, user_id, user_name, user_phone, device_id, lat, lng, wilaya_code, vehicle_type, status, trigger, peak_g, tilt, status_timestamps, responses, notified_numbers, test_mode)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
     RETURNING *;`,
    [
      alert.id,
      alert.userId,
      alert.userName,
      alert.userPhone,
      alert.deviceId,
      alert.lat,
      alert.lng,
      alert.wilayaCode,
      alert.vehicleType,
      alert.status,
      alert.trigger,
      alert.peakG,
      alert.tilt,
      JSON.stringify(alert.statusTimestamps || {}),
      JSON.stringify(alert.responses || {}),
      JSON.stringify(alert.notifiedNumbers || []),
      alert.testMode,
    ]
  );
  return res.rows[0];
}

// ---------------------------------------------------------------------------
// Hotspots & Insurance
// ---------------------------------------------------------------------------
export async function getPgHotspots(wilayaCode?: number) {
  let query = `SELECT * FROM hotspots WHERE 1=1`;
  const params: any[] = [];
  if (wilayaCode) {
    params.push(wilayaCode);
    query += ` AND wilaya_code = $${params.length}`;
  }
  query += ` ORDER BY severity, accidents_count DESC;`;
  const res = await pgPool.query(query, params);
  return res.rows.map((r: any) => ({
    id: r.id,
    title: r.title,
    description: r.description,
    lat: r.lat,
    lng: r.lng,
    wilayaCode: r.wilaya_code,
    radius: r.radius,
    severity: r.severity,
    accidentsCount: r.accidents_count,
  }));
}

export async function getPgInsurancePartners() {
  const res = await pgPool.query(`SELECT * FROM insurance_partners ORDER BY active_policies DESC;`);
  return res.rows.map((r: any) => ({
    code: r.code,
    name: r.name,
    fullNameAr: r.full_name_ar,
    commercialPlan: r.commercial_plan,
    discountPercentage: r.discount_percentage,
    contactEmail: r.contact_email,
    contactPhone: r.contact_phone,
    activePolicies: r.active_policies,
    claimsProcessed: r.claims_processed,
  }));
}

export async function getPgDatabaseStats() {
  const users = await pgPool.query("SELECT COUNT(*) FROM users;");
  const devices = await pgPool.query("SELECT COUNT(*) FROM devices;");
  const alerts = await pgPool.query("SELECT COUNT(*) FROM alerts;");
  const hotspots = await pgPool.query("SELECT COUNT(*) FROM hotspots;");
  const partners = await pgPool.query("SELECT COUNT(*) FROM insurance_partners;");

  return {
    users: Number(users.rows[0].count),
    devices: Number(devices.rows[0].count),
    alerts: Number(alerts.rows[0].count),
    hotspots: Number(hotspots.rows[0].count),
    insurancePartners: Number(partners.rows[0].count),
  };
}
