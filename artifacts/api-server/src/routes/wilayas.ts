import { Router, type Request, type Response } from "express";

const router = Router();

const WILAYAS = [
  { code: 1, name: "Adrar", nameAr: "أدرار", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 2, name: "Chlef", nameAr: "الشلف", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 3, name: "Laghouat", nameAr: "الأغواط", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 4, name: "Oum El Bouaghi", nameAr: "أم البواقي", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 5, name: "Batna", nameAr: "باتنة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 6, name: "Béjaïa", nameAr: "بجاية", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 7, name: "Biskra", nameAr: "بسكرة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 8, name: "Béchar", nameAr: "بشار", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 9, name: "Blida", nameAr: "البليدة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 10, name: "Bouira", nameAr: "البويرة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 11, name: "Tamanrasset", nameAr: "تمنراست", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 12, name: "Tébessa", nameAr: "تبسة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 13, name: "Tlemcen", nameAr: "تلمسان", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 14, name: "Tiaret", nameAr: "تيارت", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 15, name: "Tizi Ouzou", nameAr: "تيزي وزو", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 16, name: "Alger", nameAr: "الجزائر العاصمة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 17, name: "Djelfa", nameAr: "الجلفة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 18, name: "Jijel", nameAr: "جيجل", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 19, name: "Sétif", nameAr: "سطيف", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 20, name: "Saïda", nameAr: "سعيدة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 21, name: "Skikda", nameAr: "سكيكدة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 22, name: "Sidi Bel Abbès", nameAr: "سيدي بلعباس", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 23, name: "Annaba", nameAr: "عنابة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 24, name: "Guelma", nameAr: "قالمة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 25, name: "Constantine", nameAr: "قسنطينة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 26, name: "Médéa", nameAr: "المدية", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 27, name: "Mostaganem", nameAr: "مستغانم", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 28, name: "M'Sila", nameAr: "المسيلة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 29, name: "Mascara", nameAr: "معسكر", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 30, name: "Ouargla", nameAr: "ورقلة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 31, name: "Oran", nameAr: "وهران", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 32, name: "El Bayadh", nameAr: "البيض", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 33, name: "Illizi", nameAr: "إليزي", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 34, name: "Bordj Bou Arreridj", nameAr: "برج بوعريريج", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 35, name: "Boumerdès", nameAr: "بومرداس", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 36, name: "El Tarf", nameAr: "الطارف", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 37, name: "Tindouf", nameAr: "تندوف", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 38, name: "Tissemsilt", nameAr: "تيسمسيلت", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 39, name: "El Oued", nameAr: "الوادي", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 40, name: "Khenchela", nameAr: "خنشلة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 41, name: "Souk Ahras", nameAr: "سوق أهراس", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 42, name: "Tipaza", nameAr: "تيبازة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 43, name: "Mila", nameAr: "ميلة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 44, name: "Aïn Defla", nameAr: "عين الدفلى", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 45, name: "Naâma", nameAr: "النعامة", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 46, name: "Aïn Témouchent", nameAr: "عين تموشنت", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 47, name: "Ghardaïa", nameAr: "غرداية", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 48, name: "Relizane", nameAr: "غليزان", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 49, name: "Timimoun", nameAr: "تيميمون", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 50, name: "Bordj Badji Mokhtar", nameAr: "برج باجي مختار", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 51, name: "Ouled Djellal", nameAr: "أولاد جلال", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 52, name: "Béni Abbès", nameAr: "بني عباس", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 53, name: "In Salah", nameAr: "عين صالح", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 54, name: "In Guezzam", nameAr: "عين قزام", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 55, name: "Touggourt", nameAr: "تقرت", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 56, name: "Djanet", nameAr: "جانت", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 57, name: "El M'Ghair", nameAr: "المغير", police: "17", civilProtection: "14", gendarmerie: "1055" },
  { code: 58, name: "El Meniaa", nameAr: "المنيعة", police: "17", civilProtection: "14", gendarmerie: "1055" },
];

router.get("/", (req: Request, res: Response) => {
  const { code } = req.query;
  if (code) {
    const found = WILAYAS.find((w) => w.code === Number(code));
    if (!found) return res.status(404).json({ error: "Wilaya not found" });
    return res.json(found);
  }
  return res.json(WILAYAS);
});

export default router;
