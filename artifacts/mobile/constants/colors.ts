/**
 * Semantic design tokens for the mobile app.
 *
 * These tokens mirror the naming conventions used in web artifacts (index.css)
 * so that multi-artifact projects share a cohesive visual identity.
 *
 * Replace the placeholder values below with values that match the project's
 * brand. If a sibling web artifact exists, read its index.css and convert the
 * HSL values to hex so both artifacts use the same palette.
 *
 * To add dark mode, add a `dark` key with the same token names.
 * The useColors() hook will automatically pick it up.
 */

const colors = {
  light: {
    text: '#142941',
    tint: '#E36A45',
    background: '#F3F6F8',
    foreground: '#25384C',
    card: '#FFFFFF',
    cardForeground: '#142941',
    primary: '#E36A45',
    primaryForeground: '#FFFFFF',
    secondary: '#EAF0F4',
    secondaryForeground: '#2C4258',
    muted: '#EDF2F5',
    mutedForeground: '#788897',
    accent: '#FFF0E9',
    accentForeground: '#B84F2D',
    destructive: '#C94033',
    destructiveForeground: '#FFFFFF',
    border: '#DCE5EB',
    input: '#DCE5EB',
    deepNavy: '#142941',
    signal: '#E36A45',
    success: '#27856E',
    successSurface: '#E4F3ED',
    warning: '#94641C',
    warningSurface: '#FFF4DC',
    dangerSurface: '#FCEAE5',
    mapSurface: '#EAF0F3',
    mapRoad: '#D2DDE3',
    mapAccent: '#B8CCD4',
    overlay: 'rgba(8, 22, 35, 0.48)',
  },

  radius: 14,
};

export default colors;
