import pg from "pg";

const connectionString =
  process.env.DATABASE_URL ||
  "postgresql://postgres.taobdejnduuytijvflip:DendaneZaid30%40@aws-1-eu-west-3.pooler.supabase.com:6543/postgres";

console.log("Connecting to Supabase PostgreSQL...");
const client = new pg.Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  await client.connect();
  console.log("Connected to Supabase successfully!");

  console.log("Creating tables...");
  await client.query(`
    CREATE TABLE IF NOT EXISTS users (
      uid TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL DEFAULT 'slamtek123',
      phone TEXT NOT NULL,
      wilaya_code INTEGER NOT NULL DEFAULT 16,
      role TEXT NOT NULL DEFAULT 'user',
      disabled BOOLEAN NOT NULL DEFAULT false,
      vehicle_type TEXT NOT NULL DEFAULT 'car',
      test_mode BOOLEAN NOT NULL DEFAULT true,
      test_phone_number TEXT NOT NULL DEFAULT '0555999888',
      avatar_url TEXT,
      insurance_company TEXT DEFAULT 'CAAT',
      policy_number TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      vehicle_type TEXT NOT NULL DEFAULT 'car',
      connected BOOLEAN NOT NULL DEFAULT false,
      battery_level INTEGER NOT NULL DEFAULT 100,
      signal_strength INTEGER NOT NULL DEFAULT -70,
      firmware_version TEXT NOT NULL DEFAULT 'v2.1.0-esp32',
      last_seen TIMESTAMPTZ DEFAULT NOW(),
      registered_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS alerts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      user_phone TEXT NOT NULL,
      device_id TEXT NOT NULL,
      lat DOUBLE PRECISION NOT NULL,
      lng DOUBLE PRECISION NOT NULL,
      wilaya_code INTEGER NOT NULL,
      vehicle_type TEXT NOT NULL DEFAULT 'car',
      status TEXT NOT NULL DEFAULT 'sent',
      trigger TEXT NOT NULL DEFAULT 'impact',
      peak_g DOUBLE PRECISION NOT NULL DEFAULT 0,
      tilt DOUBLE PRECISION NOT NULL DEFAULT 0,
      status_timestamps JSONB DEFAULT '{}'::jsonb,
      responses JSONB DEFAULT '{}'::jsonb,
      notified_numbers JSONB DEFAULT '[]'::jsonb,
      test_mode BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS hotspots (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT DEFAULT '',
      lat DOUBLE PRECISION NOT NULL,
      lng DOUBLE PRECISION NOT NULL,
      wilaya_code INTEGER NOT NULL,
      radius INTEGER NOT NULL DEFAULT 300,
      severity TEXT NOT NULL DEFAULT 'high',
      accidents_count INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS insurance_partners (
      code TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      full_name_ar TEXT DEFAULT '',
      commercial_plan TEXT NOT NULL,
      discount_percentage INTEGER NOT NULL DEFAULT 20,
      contact_email TEXT DEFAULT '',
      contact_phone TEXT DEFAULT '',
      active_policies INTEGER NOT NULL DEFAULT 0,
      claims_processed INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS emergency_contacts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      relation TEXT NOT NULL DEFAULT 'Proche'
    );

    CREATE TABLE IF NOT EXISTS wilayas (
      code INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      name_ar TEXT DEFAULT '',
      police TEXT NOT NULL DEFAULT '17',
      civil_protection TEXT NOT NULL DEFAULT '14',
      gendarmerie TEXT NOT NULL DEFAULT '1055'
    );
  `);
  console.log("All PostgreSQL tables created successfully!");

  console.log("Inserting all accounts and seed data into Supabase...");

  // 1. Insert Users
  const users = [
    ["demo-admin-1", "Directeur Général Slamtek", "admin", "admin123", "0550000000", 16, "admin", false, "car", true, "0555999888", "/assets/images/karim.jpg", "CAAT", "ADM-2026-001"],
    ["demo-user-1", "Karim Benali", "karim", "karim123", "0555123456", 16, "user", false, "car", true, "0555999888", "/assets/images/karim.jpg", "CAAT", "POL-16-982341"],
    ["u2", "Samir Mansour", "samir", "samir123", "0770334455", 31, "user", false, "motorcycle", false, "0770334455", "/assets/assets/images/driver_moto.jpg", "SAA", "POL-31-441199"],
    ["u3", "Nadia Khelifi", "nadia", "nadia123", "0661556677", 9, "user", false, "car", false, "0661556677", "/assets/assets/images/driver_woman.jpg", "CIAR", "POL-09-556677"],
    ["u4", "Mohamed Larbi", "mohamed_l", "mohamed123", "0550112233", 25, "user", false, "car", false, "0550112233", "/assets/assets/images/driver_casual.jpg", "CASH", "POL-25-112233"],
    ["u5", "Amina Zerrouki", "amina_z", "amina123", "0662334455", 19, "user", false, "car", false, "0662334455", "/assets/assets/images/driver_woman.jpg", "Macir Vie", "POL-19-223344"],
    ["u6", "Yacine Mansouri", "yacine_m", "yacine123", "0771889900", 31, "user", false, "motorcycle", false, "0771889900", null, "SAA", null],
    ["u7", "Dr. Meriem Saidi", "meriem_s", "meriem123", "0555443322", 25, "user", false, "car", false, "0555443322", null, "CAAT", null],
    ["u8", "Sofiane Bouzid", "sofiane_b", "sofiane123", "0663778899", 19, "user", false, "car", false, "0663778899", null, "CIAR", null],
    ["u9", "Bilal Haddad", "bilal_h", "bilal123", "0772112233", 9, "user", false, "motorcycle", false, "0772112233", null, "Trust", null],
    ["u10", "Ryad Belkacem", "ryad_b", "ryad123", "0551998877", 23, "user", false, "car", false, "0551998877", null, "CAAT", null],
    ["auth-civil-protection", "Protection Civile Algérienne", "protection_civile", "protection123", "14", 16, "civil_protection", false, "truck", false, "14", null, "État", null],
    ["auth-police", "DGSN - Sûreté Nationale", "police_nationale", "police123", "17", 16, "police", false, "car", false, "17", null, "État", null],
    ["ins-caat", "CAAT Assurances", "assurance_caat", "caat123", "021000100", 16, "insurance", false, "car", false, "021000100", null, "CAAT", null],
    ["ins-saa", "SAA Assurances", "assurance_saa", "saa123", "021000200", 16, "insurance", false, "car", false, "021000200", null, "SAA", null],
    ["ins-ciar", "CIAR Assurances", "assurance_ciar", "ciar123", "021000300", 16, "insurance", false, "car", false, "021000300", null, "CIAR", null],
  ];

  for (const u of users) {
    await client.query(
      `INSERT INTO users (uid, full_name, username, password, phone, wilaya_code, role, disabled, vehicle_type, test_mode, test_phone_number, avatar_url, insurance_company, policy_number)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       ON CONFLICT (uid) DO UPDATE SET
         full_name = EXCLUDED.full_name,
         username = EXCLUDED.username,
         password = EXCLUDED.password,
         phone = EXCLUDED.phone,
         role = EXCLUDED.role,
         vehicle_type = EXCLUDED.vehicle_type,
         insurance_company = EXCLUDED.insurance_company;`,
      u
    );
  }
  console.log(`Inserted ${users.length} accounts!`);

  // 2. Insert Devices
  const devices = [
    ["SOLVEX-A101", "demo-user-1", "Slamtek ESP32-Box #101", "car", true, 98, -68, "v2.1.0-esp32"],
    ["SOLVEX-M102", "u2", "Slamtek Moto-Box #102", "motorcycle", true, 92, -72, "v2.1.0-esp32"],
    ["SOLVEX-A103", "u3", "Slamtek Auto-Box #103", "car", false, 84, -80, "v2.1.0-esp32"],
    ["SOLVEX-A104", "u4", "Slamtek Auto-Box #104", "car", true, 99, -65, "v2.1.0-esp32"],
  ];
  for (const d of devices) {
    await client.query(
      `INSERT INTO devices (id, user_id, name, vehicle_type, connected, battery_level, signal_strength, firmware_version)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET connected = EXCLUDED.connected, battery_level = EXCLUDED.battery_level;`,
      d
    );
  }
  console.log(`Inserted ${devices.length} IoT devices!`);

  // 3. Insert Hotspots
  const hotspots = [
    ["hp-chiffa", "Gorges de Chiffa (RN1) - Blida", "Virages dangereux et brouillard", 36.4251, 2.7654, 9, 400, "high", 47],
    ["hp-djebahia", "Descente de Djebahia (Autoroute Est-Ouest)", "Pente abrupte de 6 km", 36.5123, 3.7541, 10, 600, "high", 68],
    ["hp-kouba", "Échangeur Oued Ouchayah / Rocade Sud - Alger", "Ralentissement imprévu et vitesse", 36.7214, 3.0821, 16, 350, "medium", 32],
    ["hp-corniche", "Corniche Oranaise (Mers El Kébir) - Oran", "Route sinueuse en bord de mer", 35.7312, -0.6891, 31, 450, "high", 39],
    ["hp-constantine", "Descente du Pont Géant - Constantine", "Pente forte et verglas", 36.3654, 6.6147, 25, 300, "medium", 28],
  ];
  for (const h of hotspots) {
    await client.query(
      `INSERT INTO hotspots (id, title, description, lat, lng, wilaya_code, radius, severity, accidents_count)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, accidents_count = EXCLUDED.accidents_count;`,
      h
    );
  }
  console.log(`Inserted ${hotspots.length} Points Noirs!`);

  // 4. Insert Insurance Partners
  const partners = [
    ["caat", "CAAT Assurances", "الشركة الجزائرية للتأمينات", "Formule Tout Risque + Boîtier Slamtek Inclus", 25, "slamtek@caat.dz", "021000100", 1840, 42],
    ["saa", "SAA Assurances", "الشركة الوطنية للتأمين", "Pack Sécurité Routière & Détection Rapide", 20, "partenariat@saa.dz", "021000200", 2450, 67],
    ["ciar", "CIAR Assurances", "الشركة الدولية للتأمين", "Contrat Connecté Assistance 24/7", 18, "contact@ciar.dz", "021000300", 920, 19],
    ["cash", "CASH Assurances", "شركة التأمين للمحروقات", "Flottes Entreprises & Particuliers", 22, "flottes@cash.dz", "021000400", 630, 14],
    ["macir_vie", "Macir Vie", "ماصير في للتأمين", "Assurance Conducteur & Passagers", 15, "info@macirvie.com", "021000500", 410, 8],
  ];
  for (const p of partners) {
    await client.query(
      `INSERT INTO insurance_partners (code, name, full_name_ar, commercial_plan, discount_percentage, contact_email, contact_phone, active_policies, claims_processed)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (code) DO UPDATE SET active_policies = EXCLUDED.active_policies;`,
      p
    );
  }
  console.log(`Inserted ${partners.length} Insurance Partners!`);

  // 5. Insert Alerts
  await client.query(`
    INSERT INTO alerts (id, user_id, user_name, user_phone, device_id, lat, lng, wilaya_code, vehicle_type, status, trigger, peak_g, tilt, status_timestamps, responses, notified_numbers, test_mode)
    VALUES (
      'a1',
      'demo-user-1',
      'Karim Benali',
      '0555123456',
      'SOLVEX-A101',
      36.7538,
      3.0588,
      16,
      'car',
      'arrived',
      'impact',
      4.8,
      14.5,
      '{"sent": "2026-10-30T14:45:00Z", "arrived": "2026-10-30T15:05:00Z"}'::jsonb,
      '{"police": {"status": "arrived"}, "civilProtection": {"status": "arrived"}}'::jsonb,
      '["0551223344", "0661998877"]'::jsonb,
      true
    )
    ON CONFLICT (id) DO NOTHING;
  `);
  console.log("Inserted sample Alerts!");

  // Verify counts
  const uCount = await client.query("SELECT COUNT(*) FROM users;");
  const dCount = await client.query("SELECT COUNT(*) FROM devices;");
  const hCount = await client.query("SELECT COUNT(*) FROM hotspots;");
  const pCount = await client.query("SELECT COUNT(*) FROM insurance_partners;");

  console.log("\n--- Supabase Database Ready ---");
  console.log("Users in Supabase:", uCount.rows[0].count);
  console.log("Devices in Supabase:", dCount.rows[0].count);
  console.log("Hotspots in Supabase:", hCount.rows[0].count);
  console.log("Insurance Partners in Supabase:", pCount.rows[0].count);

  await client.end();
  console.log("\nSetup finished successfully!");
}

run().catch((err) => {
  console.error("Setup failed:", err);
  process.exit(1);
});
