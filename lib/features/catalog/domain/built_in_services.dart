import 'service_item.dart';
import 'slug.dart';

const kServiceCategoryArchitecture = 'Architecture';
const kServiceCategoryBuilding = 'Building';
const kServiceCategoryRenovation = 'Renovation';
const kServiceCategoryInteriors = 'Interiors';
const kServiceCategoryCommercial = 'Commercial';
const kServiceCategoryAddons = 'Add-ons';

ServiceItem? builtInServiceByIdOrSlug(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  for (final item in builtInServices) {
    if (item.id == value || item.slug == value) return item;
  }
  return null;
}

List<ServiceItem> mergeCatalogServices(List<ServiceItem> remote, {bool activeOnly = true}) {
  final slugs = {for (final item in remote) item.slug};
  final extras = [
    for (final item in builtInServices)
      if (!slugs.contains(item.slug) && (!activeOnly || item.isActive)) item,
  ];
  return [...remote, ...extras]..sort((a, b) => (a.sortOrder ?? 9999).compareTo(b.sortOrder ?? 9999));
}

ServiceItem _svc({
  required String title,
  required String category,
  required String shortDescription,
  required String longDescription,
  required String icon,
  required int sortOrder,
  double? startingPrice,
  String? priceUnit,
}) {
  final slug = catalogSlug(title);
  return ServiceItem(
    id: 'svc_$slug',
    title: title,
    slug: slug,
    category: category,
    shortDescription: shortDescription,
    longDescription: longDescription,
    icon: icon,
    startingPrice: startingPrice,
    priceUnit: priceUnit,
    isActive: true,
    sortOrder: sortOrder,
  );
}

final builtInServices = <ServiceItem>[
  _svc(
    title: 'House and villa planning',
    category: kServiceCategoryArchitecture,
    icon: 'architecture',
    sortOrder: 10,
    startingPrice: 25000,
    priceUnit: 'project',
    shortDescription: 'New house, villa, or farmhouse layout on your plot.',
    longDescription:
        'Site study, room planning, and vastu-aware layouts for independent houses and villas. You get a usable floor plan before civil work starts.',
  ),
  _svc(
    title: '2BHK / 3BHK / duplex layout',
    category: kServiceCategoryArchitecture,
    icon: 'architecture',
    sortOrder: 11,
    startingPrice: 15000,
    priceUnit: 'project',
    shortDescription: 'Best-use floor plan for flats and duplexes.',
    longDescription:
        'We rework circulation, kitchen, bedrooms, and storage so a 2BHK, 3BHK, or duplex feels larger and works for how your family lives.',
  ),
  _svc(
    title: 'Floor plan and 3D views',
    category: kServiceCategoryArchitecture,
    icon: 'architecture',
    sortOrder: 12,
    startingPrice: 18000,
    priceUnit: 'project',
    shortDescription: 'Plans plus 3D so the family can decide together.',
    longDescription:
        '2D working plans with 3D stills or a short walkthrough. Useful before you lock interiors, civil changes, or a builder quote.',
  ),
  _svc(
    title: 'Vastu consultation',
    category: kServiceCategoryArchitecture,
    icon: 'consult',
    sortOrder: 13,
    startingPrice: 8000,
    priceUnit: 'visit',
    shortDescription: 'Vastu-compliant plan or corrections on an existing home.',
    longDescription:
        'Entrance, kitchen, bedroom, and pooja placement reviewed against vastu. We mark practical changes that still pass municipal rules.',
  ),
  _svc(
    title: 'Municipal building plan approval',
    category: kServiceCategoryArchitecture,
    icon: 'consult',
    sortOrder: 14,
    startingPrice: 35000,
    priceUnit: 'project',
    shortDescription: 'Corporation / nagar nigam drawings and filing support.',
    longDescription:
        'Setbacks, FAR/FSI, and submission drawings for municipal or development-authority approval. Liaison is scoped after a site visit.',
  ),
  _svc(
    title: 'Structural and working drawings',
    category: kServiceCategoryArchitecture,
    icon: 'architecture',
    sortOrder: 15,
    startingPrice: 40000,
    priceUnit: 'project',
    shortDescription: 'RCC, electrical, and plumbing drawings for the contractor.',
    longDescription:
        'Construction-ready drawings so civil, electrical, and plumbing teams build from one set — not WhatsApp sketches.',
  ),
  _svc(
    title: 'Elevation design',
    category: kServiceCategoryArchitecture,
    icon: 'architecture',
    sortOrder: 16,
    startingPrice: 20000,
    priceUnit: 'project',
    shortDescription: 'Front look: modern, contemporary, or Indian.',
    longDescription:
        'Facade, material, and lighting intent for the street elevation, with options your family can pick before stone or paint is ordered.',
  ),
  _svc(
    title: 'Plot feasibility study',
    category: kServiceCategoryArchitecture,
    icon: 'consult',
    sortOrder: 17,
    startingPrice: 12000,
    priceUnit: 'plot',
    shortDescription: 'What you can legally build on this plot.',
    longDescription:
        'Coverage, setbacks, height, parking, and a first-cut built-up area so you buy or build with eyes open.',
  ),
  _svc(
    title: 'Site supervision / PMC',
    category: kServiceCategoryArchitecture,
    icon: 'consult',
    sortOrder: 18,
    startingPrice: 25000,
    priceUnit: 'month',
    shortDescription: 'We visit site and keep the contractor on drawing.',
    longDescription:
        'Weekly or fortnightly site visits, quality checks, and a simple progress note. You stay in control without living on site.',
  ),
  _svc(
    title: 'Turnkey house construction',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 30,
    startingPrice: 2200,
    priceUnit: 'sqft',
    shortDescription: 'Key-ready house: civil to paint.',
    longDescription:
        'Foundation to handover — RCC, brick, plaster, waterproofing, electrical, plumbing, doors, flooring, and paint. Finishes are locked in a BOQ before work starts.',
  ),
  _svc(
    title: 'Civil and finishing package',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 31,
    startingPrice: 1600,
    priceUnit: 'sqft',
    shortDescription: 'Structure plus basic finishing, without interiors.',
    longDescription:
        'Grey structure and standard finishing (plaster, flooring, bathrooms, kitchen platform, paint). Modular kitchen and furniture are extra.',
  ),
  _svc(
    title: 'Foundation and RCC frame',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 32,
    startingPrice: 900,
    priceUnit: 'sqft',
    shortDescription: 'Plinth, columns, beams, and slabs.',
    longDescription:
        'Excavation, footing, plinth beam, columns, and slabs as per structural drawing. Includes curing and basic quality checks.',
  ),
  _svc(
    title: 'Brickwork, plaster, and waterproofing',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 33,
    startingPrice: 450,
    priceUnit: 'sqft',
    shortDescription: 'Walls, plaster, terrace and wet-area waterproofing.',
    longDescription:
        'AAC or brick walls, internal/external plaster, and waterproofing for terrace, bathrooms, and kitchen wet areas.',
  ),
  _svc(
    title: 'Plumbing and overhead tank work',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 34,
    startingPrice: 45000,
    priceUnit: 'home',
    shortDescription: 'CPVC/PPR lines, tanks, and sanitary points.',
    longDescription:
        'Water supply, drainage, overhead/underground tank connections, and bathroom/kitchen points. Borewell piping if the plot needs it.',
  ),
  _svc(
    title: 'Electrical and inverter-ready wiring',
    category: kServiceCategoryBuilding,
    icon: 'light',
    sortOrder: 35,
    startingPrice: 350,
    priceUnit: 'sqft',
    shortDescription: 'Points, DB, earthing, inverter and solar-ready.',
    longDescription:
        'Concealed wiring, boards, earthing, and a DB plan that can take inverter or rooftop solar later without ripping walls.',
  ),
  _svc(
    title: 'Doors, windows, and grills',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 36,
    startingPrice: 18000,
    priceUnit: 'opening',
    shortDescription: 'UPVC, aluminium, or wooden openings plus safety grills.',
    longDescription:
        'Measured openings, hardware, and grill/railing as specified. We quote after a site measure.',
  ),
  _svc(
    title: 'Compound wall, gate, and parking',
    category: kServiceCategoryBuilding,
    icon: 'building',
    sortOrder: 37,
    startingPrice: 2800,
    priceUnit: 'rft',
    shortDescription: 'Boundary, gate, and driveway.',
    longDescription:
        'Boundary wall, main gate, and parking or cobble/interlock driveway so the plot is usable from day one.',
  ),
  _svc(
    title: 'Full home renovation',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 50,
    startingPrice: 1400,
    priceUnit: 'sqft',
    shortDescription: 'Purana ghar naya — civil, electrical, paint, wet areas.',
    longDescription:
        'Dismantling, rewiring, plumbing, bathrooms, kitchen, flooring, false ceiling, and paint. Phased so a family can stay in part of the house if needed.',
  ),
  _svc(
    title: '2BHK / 3BHK makeover',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 51,
    startingPrice: 350000,
    priceUnit: 'flat',
    shortDescription: 'Society-flat refresh with debris and timing rules.',
    longDescription:
        'Paint, flooring, kitchen, bathrooms, and lighting for a 2BHK or 3BHK. We work to society hours and debris-pass rules.',
  ),
  _svc(
    title: 'Kitchen renovation',
    category: kServiceCategoryRenovation,
    icon: 'kitchen',
    sortOrder: 52,
    startingPrice: 180000,
    priceUnit: 'kitchen',
    shortDescription: 'Modular kitchen, chimney, hob, and granite or quartz.',
    longDescription:
        'Layout, plumbing, electrical, counter, chimney/hob, and shutters. Brands (Hettich, Hafele, Blum, and Indian makes) are locked in the quote.',
  ),
  _svc(
    title: 'Bathroom renovation',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 53,
    startingPrice: 85000,
    priceUnit: 'bathroom',
    shortDescription: 'Tiles, sanitary, leak fix, and glass partition.',
    longDescription:
        'Hack-out, waterproofing, tiles, WC, basin, mixer, geyser point, and optional glass partition. Seepage jobs start with a leak diagnosis.',
  ),
  _svc(
    title: 'Waterproofing and seepage repair',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 54,
    startingPrice: 180,
    priceUnit: 'sqft',
    shortDescription: 'Terrace, bathroom, and wall seepage.',
    longDescription:
        'Find the leak path, treat, and re-tile or re-plaster the affected area. We do not just paint over damp.',
  ),
  _svc(
    title: 'Flooring change',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 55,
    startingPrice: 160,
    priceUnit: 'sqft',
    shortDescription: 'Remove old tiles; lay vitrified, SPC, or marble.',
    longDescription:
        'Removal, levelling, and new flooring. Living, bedrooms, and wet areas can use different materials in one visit.',
  ),
  _svc(
    title: 'Rewiring and plumbing replacement',
    category: kServiceCategoryRenovation,
    icon: 'light',
    sortOrder: 56,
    startingPrice: 280,
    priceUnit: 'sqft',
    shortDescription: 'Old-house GI/aluminium to CPVC and new circuits.',
    longDescription:
        'Replace ageing plumbing and electrical without a full interiors package. Essential before you put new tiles or a modular kitchen.',
  ),
  _svc(
    title: 'Wall shifting and open kitchen',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 57,
    startingPrice: 45000,
    priceUnit: 'opening',
    shortDescription: 'Break or shift walls after a structural check.',
    longDescription:
        'We confirm what is load-bearing, then open the kitchen or merge rooms. Includes debris, making-good, and a lintel if required.',
  ),
  _svc(
    title: 'Balcony enclosure and terrace sit-out',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 58,
    startingPrice: 65000,
    priceUnit: 'area',
    shortDescription: 'Utility balcony, glass enclosure, or terrace deck.',
    longDescription:
        'Waterproofing, flooring, railing, and a simple sit-out or utility layout. Society and municipal rules are checked first.',
  ),
  _svc(
    title: 'Rental refresh',
    category: kServiceCategoryRenovation,
    icon: 'renovation',
    sortOrder: 59,
    startingPrice: 75000,
    priceUnit: 'flat',
    shortDescription: 'Fast paint, lights, and basic kitchen for rent-out.',
    longDescription:
        'A short, cheap package: paint, basic lights, tap/sanitary fixes, and a usable kitchen so the flat can be listed.',
  ),
  _svc(
    title: 'Turnkey home interiors',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 70,
    startingPrice: 1800,
    priceUnit: 'sqft',
    shortDescription: 'Design plus execution for the full home.',
    longDescription:
        'False ceiling, lighting, modular kitchen, wardrobes, TV unit, paint, and loose furniture as one package. Amount stays quantity × rate in the estimate.',
  ),
  _svc(
    title: 'Interior design only',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 71,
    startingPrice: 80,
    priceUnit: 'sqft',
    shortDescription: 'Drawings, 3D, and BOQ — you execute.',
    longDescription:
        'Mood, 3D, working drawings, and a brand-wise BOQ. You can bid it to your own carpenter or come back to us for execution.',
  ),
  _svc(
    title: 'Per-sqft interiors package',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 72,
    startingPrice: 1600,
    priceUnit: 'sqft',
    shortDescription: 'Fixed-scope interiors quoted per square foot.',
    longDescription:
        'A published scope (ceiling, lights, kitchen, wardrobes, paint) at a per-sqft rate. Extra items are listed separately so the number stays honest.',
  ),
  _svc(
    title: 'Modular kitchen',
    category: kServiceCategoryInteriors,
    icon: 'kitchen',
    sortOrder: 73,
    startingPrice: 150000,
    priceUnit: 'kitchen',
    shortDescription: 'Carcass, shutters, tandem boxes, chimney, and hob.',
    longDescription:
        'Measured modular kitchen with accessories. Soft-close, tall unit, and appliance cut-outs included in the quote.',
  ),
  _svc(
    title: 'Wardrobes and loft storage',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 74,
    startingPrice: 1400,
    priceUnit: 'sqft shutter',
    shortDescription: 'Sliding or hinged wardrobes with loft.',
    longDescription:
        'Bedroom and foyer wardrobes, lofts, and dressing units. Finish and internals are chosen before fabrication.',
  ),
  _svc(
    title: 'Living and dining interiors',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 75,
    startingPrice: 85000,
    priceUnit: 'area',
    shortDescription: 'TV unit, ceiling, lights, and dining storage.',
    longDescription:
        'TV panel, false ceiling, cove lights, wallpaper or panelling, and a dining or crockery unit.',
  ),
  _svc(
    title: 'Master bedroom interiors',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 76,
    startingPrice: 120000,
    priceUnit: 'room',
    shortDescription: 'Bed back, wardrobe, dressing, and lighting.',
    longDescription:
        'A complete master bedroom: wardrobe, bed back, dressing, blackout-ready lighting, and optional TV panel.',
  ),
  _svc(
    title: 'Kids room and study',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 77,
    startingPrice: 75000,
    priceUnit: 'room',
    shortDescription: 'Study, bunk or single bed, and wardrobe.',
    longDescription:
        'Safe storage, study desk, and a sleep zone that can grow with the child. Soft finishes and pin-up walls on request.',
  ),
  _svc(
    title: 'Pooja unit / mandir',
    category: kServiceCategoryInteriors,
    icon: 'interior',
    sortOrder: 78,
    startingPrice: 28000,
    priceUnit: 'unit',
    shortDescription: 'Wall or floor mandir with lighting.',
    longDescription:
        'Jaali, marble, or laminate mandir with storage for pooja items and a dedicated light circuit.',
  ),
  _svc(
    title: 'False ceiling and lighting design',
    category: kServiceCategoryInteriors,
    icon: 'light',
    sortOrder: 79,
    startingPrice: 140,
    priceUnit: 'sqft',
    shortDescription: 'Gypsum/POP ceiling, cove, and layer lighting.',
    longDescription:
        'Ceiling plan plus a lighting layout (ambient, task, accent) so electrical is done once.',
  ),
  _svc(
    title: 'Home office / WFH cabin',
    category: kServiceCategoryInteriors,
    icon: 'office',
    sortOrder: 80,
    startingPrice: 55000,
    priceUnit: 'cabin',
    shortDescription: 'Quiet desk, storage, and lighting for work from home.',
    longDescription:
        'A compact cabin or study nook with cable management, acoustic softness, and a door if the flat allows.',
  ),
  _svc(
    title: 'Office fit-out',
    category: kServiceCategoryCommercial,
    icon: 'office',
    sortOrder: 90,
    startingPrice: 1600,
    priceUnit: 'sqft',
    shortDescription: 'Workstations, cabins, pantry, and toilets.',
    longDescription:
        'Turnkey office interiors: civil, partitions, electrical, HVAC coordination, furniture, and branding wall. Matches our estimate catalog.',
  ),
  _svc(
    title: 'Reception and conference interiors',
    category: kServiceCategoryCommercial,
    icon: 'office',
    sortOrder: 91,
    startingPrice: 95000,
    priceUnit: 'area',
    shortDescription: 'Reception desk, waiting, and meeting room.',
    longDescription:
        'Reception, waiting lounge, and conference with glass or gypsum partitions and AV-ready electrical.',
  ),
  _svc(
    title: 'Clinic, salon, or studio interiors',
    category: kServiceCategoryCommercial,
    icon: 'office',
    sortOrder: 92,
    startingPrice: 1800,
    priceUnit: 'sqft',
    shortDescription: 'Treatment rooms, reception, and wet areas.',
    longDescription:
        'Layout for patient or client flow, privacy, plumbing for chairs/basins, and easy-clean finishes.',
  ),
  _svc(
    title: 'Shop, showroom, or boutique',
    category: kServiceCategoryCommercial,
    icon: 'office',
    sortOrder: 93,
    startingPrice: 1500,
    priceUnit: 'sqft',
    shortDescription: 'Display, lighting, and billing counter.',
    longDescription:
        'Retail interiors: display, lighting, cash desk, and a store. We work around trading hours where needed.',
  ),
  _svc(
    title: 'Cafe or restaurant interiors',
    category: kServiceCategoryCommercial,
    icon: 'office',
    sortOrder: 94,
    startingPrice: 2000,
    priceUnit: 'sqft',
    shortDescription: 'Seating, kitchen exhaust, and wash-up.',
    longDescription:
        'F&B layout with seating mix, service path, kitchen/exhaust coordination, and wash-up. Licences stay with the operator.',
  ),
  _svc(
    title: 'Shop or office renovation',
    category: kServiceCategoryCommercial,
    icon: 'renovation',
    sortOrder: 95,
    startingPrice: 900,
    priceUnit: 'sqft',
    shortDescription: 'Refresh while the business stays open.',
    longDescription:
        'Phased dismantling and finishing so the shop or office can keep working. Night or weekend shifts on request.',
  ),
  _svc(
    title: '3D walkthrough',
    category: kServiceCategoryAddons,
    icon: 'architecture',
    sortOrder: 110,
    startingPrice: 15000,
    priceUnit: 'project',
    shortDescription: 'Animated walkthrough of the approved design.',
    longDescription: 'A short rendered walkthrough after the 3D stills are signed off.',
  ),
  _svc(
    title: 'Material and brand selection',
    category: kServiceCategoryAddons,
    icon: 'consult',
    sortOrder: 111,
    startingPrice: 8000,
    priceUnit: 'visit',
    shortDescription: 'Tiles, sanitary, plywood, and paint shortlist.',
    longDescription:
        'Market or showroom visit with a locked brand list (tiles, Jaquar-class sanitary, plywood, laminates, paints) for the BOQ.',
  ),
  _svc(
    title: 'Site visit and measurement',
    category: kServiceCategoryAddons,
    icon: 'consult',
    sortOrder: 112,
    startingPrice: 2500,
    priceUnit: 'visit',
    shortDescription: 'Measure, photos, and a first note.',
    longDescription:
        'NCR site visit, tape measure, and a one-page observation note. Adjustable against a later design or execution order.',
  ),
  _svc(
    title: 'Home automation',
    category: kServiceCategoryAddons,
    icon: 'light',
    sortOrder: 113,
    startingPrice: 45000,
    priceUnit: 'home',
    shortDescription: 'Lights, curtains, and video door.',
    longDescription:
        'Basic automation: lighting scenes, curtain motors, and video door. Wired during interiors so you do not chase the walls later.',
  ),
  _svc(
    title: 'AC and VRV planning',
    category: kServiceCategoryAddons,
    icon: 'consult',
    sortOrder: 114,
    startingPrice: 12000,
    priceUnit: 'project',
    shortDescription: 'Indoor units, copper, and drain coordinated with ceiling.',
    longDescription:
        'AC load and placement so false ceiling and copper runs are drawn once. Supply of machines can be owner or us.',
  ),
  _svc(
    title: 'Curtains, wallpaper, and loose furniture',
    category: kServiceCategoryAddons,
    icon: 'interior',
    sortOrder: 115,
    startingPrice: 25000,
    priceUnit: 'home',
    shortDescription: 'Soft furnishings after the carpenter leaves.',
    longDescription:
        'Curtains, wallpaper, rugs, and loose sofas/beds sourced to the approved mood board.',
  ),
  _svc(
    title: 'Handover clean and snag list',
    category: kServiceCategoryAddons,
    icon: 'consult',
    sortOrder: 116,
    startingPrice: 8000,
    priceUnit: 'home',
    shortDescription: 'Deep clean plus a written snag punch.',
    longDescription:
        'Handover clean, snag walk, and a close-out list so retainership is clear.',
  ),
];
