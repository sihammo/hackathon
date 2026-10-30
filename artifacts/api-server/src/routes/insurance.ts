import { Router, type Request, type Response } from "express";
import { InsurancePartnerModel } from "../models";
import { SEED_INSURANCE_PARTNERS, isMongoConnected } from "../lib/db";
import { getPgInsurancePartners, isPgConnected } from "../lib/postgres";

const router = Router();
let memoryPartners = [...SEED_INSURANCE_PARTNERS];

// GET /api/insurance/partners
router.get("/partners", async (req: Request, res: Response) => {
  try {
    try {
      const pgPartners = await getPgInsurancePartners();
      if (pgPartners.length > 0) return res.json(pgPartners);
    } catch {
      // Fallback
    }

    if (isMongoConnected()) {
      const partners = await InsurancePartnerModel.find().sort({ activePolicies: -1 });
      return res.json(partners);
    }
    return res.json(memoryPartners);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/insurance/stats
router.get("/stats", async (req: Request, res: Response) => {
  return res.json({
    success: true,
    partnerSummary: "Partenariats Assurances Algériennes - CAAT, SAA, CIAR, CASH, Macir Vie",
    database: isPgConnected() ? "supabase_postgresql" : isMongoConnected() ? "mongodb" : "in_memory",
    metrics: {
      totalInsuredVehicles: 6250,
      activeSlamtekBoxes: 1240,
      averageResponseTimeMinutes: 7.4,
      fraudReductionPercentage: 68.5,
      riskReductionPercentage: 35.0,
      claimsProcessed2026: 4,
      safeDriversPercentage: 94.2,
    },
  });
});

export default router;
