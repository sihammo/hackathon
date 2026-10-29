import { Feather } from '@expo/vector-icons';
import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleProp,
  StyleSheet,
  Text,
  TextInput,
  TextInputProps,
  TextStyle,
  View,
  ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '@/lib/app-context';
import { t, wilayasFor } from '@/lib/i18n';
import { useColors } from '@/hooks/useColors';

export function Page({
  children,
  contentStyle,
  scroll = true,
}: {
  children: React.ReactNode;
  contentStyle?: StyleProp<ViewStyle>;
  scroll?: boolean;
}) {
  const insets = useSafeAreaInsets();
  const colors = useColors();
  const { data } = useApp();
  const direction = data.language === 'ar' ? 'rtl' : 'ltr';
  const top = Platform.OS === 'web' ? Math.max(insets.top, 67) + 12 : insets.top + 12;
  const bottom = Platform.OS === 'web' ? 120 : insets.bottom + 30;
  const styles = useMemo(() => makeStyles(colors), [colors]);
  if (!scroll) {
    return (
      <View style={[styles.page, { paddingTop: top, paddingBottom: bottom, direction }, contentStyle]}>
        {children}
      </View>
    );
  }
  return (
    <ScrollView
      style={[styles.page, { direction }]}
      contentContainerStyle={[styles.pageContent, { paddingTop: top, paddingBottom: bottom, direction }, contentStyle]}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  );
}

export function AppText({
  children,
  style,
  ...props
}: React.ComponentProps<typeof Text>) {
  const { data } = useApp();
  const colors = useColors();
  const direction: TextStyle = {
    color: colors.foreground,
    writingDirection: data.language === 'ar' ? 'rtl' : 'ltr',
    textAlign: data.language === 'ar' ? 'right' : 'left',
  };
  return (
    <Text {...props} style={[direction, style]}>
      {children}
    </Text>
  );
}

export function Heading({ children }: { children: React.ReactNode }) {
  const colors = useColors();
  return <AppText style={{ fontSize: 27, fontWeight: '700', letterSpacing: -0.7, color: colors.deepNavy }}>{children}</AppText>;
}

export function SectionTitle({
  children,
  trailing,
}: {
  children: React.ReactNode;
  trailing?: React.ReactNode;
}) {
  const colors = useColors();
  return (
    <View style={styles.rowBetween}>
      <AppText style={{ color: colors.deepNavy, fontSize: 17, fontWeight: '700', flex: 1 }}>{children}</AppText>
      {trailing}
    </View>
  );
}

export function Card({
  children,
  style,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  const colors = useColors();
  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.border,
          borderRadius: colors.radius + 10,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}

export function ActionButton({
  label,
  onPress,
  icon,
  variant = 'primary',
  disabled = false,
  testID,
  style,
}: {
  label: string;
  onPress: () => void;
  icon?: keyof typeof Feather.glyphMap;
  variant?: 'primary' | 'secondary' | 'danger' | 'outline';
  disabled?: boolean;
  testID?: string;
  style?: StyleProp<ViewStyle>;
}) {
  const colors = useColors();
  const fills = {
    primary: colors.deepNavy,
    secondary: colors.secondary,
    danger: colors.signal,
    outline: colors.card,
  };
  const foregrounds = {
    primary: colors.primaryForeground,
    secondary: colors.secondaryForeground,
    danger: colors.primaryForeground,
    outline: colors.foreground,
  };
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      testID={testID}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        {
          backgroundColor: fills[variant],
          borderColor: variant === 'outline' ? colors.border : fills[variant],
          opacity: disabled ? 0.5 : pressed ? 0.82 : 1,
          transform: [{ scale: pressed ? 0.985 : 1 }],
        },
        style,
      ]}
    >
      {icon ? <Feather name={icon} size={17} color={foregrounds[variant]} /> : null}
      <Text style={[styles.buttonText, { color: foregrounds[variant] }]}>{label}</Text>
    </Pressable>
  );
}

export function Input({
  label,
  error,
  ...props
}: TextInputProps & { label: string; error?: string }) {
  const colors = useColors();
  const { data } = useApp();
  return (
    <View style={{ gap: 7 }}>
      <AppText style={{ fontSize: 13, fontWeight: '600', color: colors.mutedForeground }}>{label}</AppText>
      <TextInput
        {...props}
        placeholderTextColor={colors.mutedForeground}
        style={[
          styles.input,
          {
            backgroundColor: colors.card,
            borderColor: error ? colors.signal : colors.border,
            color: colors.foreground,
            textAlign: data.language === 'ar' ? 'right' : 'left',
            writingDirection: data.language === 'ar' ? 'rtl' : 'ltr',
          },
          props.style,
        ]}
      />
      {error ? <AppText style={{ color: colors.signal, fontSize: 12 }}>{error}</AppText> : null}
    </View>
  );
}

export function Badge({
  children,
  tone = 'neutral',
}: {
  children: React.ReactNode;
  tone?: 'neutral' | 'success' | 'warning' | 'danger';
}) {
  const colors = useColors();
  const values = {
    neutral: [colors.secondary, colors.secondaryForeground],
    success: [colors.successSurface, colors.success],
    warning: [colors.warningSurface, colors.warning],
    danger: [colors.dangerSurface, colors.signal],
  };
  const [backgroundColor, color] = values[tone];
  return (
    <View style={[styles.badge, { backgroundColor }]}>
      <AppText style={{ color, fontSize: 11, fontWeight: '700' }}>{children}</AppText>
    </View>
  );
}

export function DemoBanner() {
  const { data } = useApp();
  const colors = useColors();
  return (
    <View style={[styles.demoBanner, { backgroundColor: colors.warningSurface, borderColor: colors.warning }]}>
      <Feather name="shield" size={17} color={colors.warning} />
      <View style={{ flex: 1, gap: 2 }}>
        <AppText style={{ fontSize: 11, color: colors.warning, fontWeight: '800', letterSpacing: 0.35 }}>
          {t(data.language, 'demoOnly')}
        </AppText>
        <AppText style={{ fontSize: 12, color: colors.foreground, lineHeight: 17 }}>
          {t(data.language, 'demoDetails')}
        </AppText>
      </View>
    </View>
  );
}

export function WilayaPicker({
  value,
  onSelect,
  label,
}: {
  value: string;
  onSelect: (wilaya: string) => void;
  label?: string;
}) {
  const { data } = useApp();
  const colors = useColors();
  const [visible, setVisible] = useState(false);
  const [query, setQuery] = useState('');
  const options = wilayasFor(data.language);
  const filtered = options.filter((item) => item.toLocaleLowerCase().includes(query.toLocaleLowerCase()));
  const frenchIndex = wilayasFor('fr').indexOf(value);
  const shownValue = frenchIndex >= 0 ? options[frenchIndex] : value;
  return (
    <>
      <View style={{ gap: 7 }}>
        {label ? <AppText style={{ fontSize: 13, fontWeight: '600', color: colors.mutedForeground }}>{label}</AppText> : null}
        <Pressable
          testID="wilaya-picker"
          accessibilityRole="button"
          onPress={() => {
            setQuery('');
            setVisible(true);
          }}
          style={[styles.input, styles.rowBetween, { backgroundColor: colors.card, borderColor: colors.border }]}
        >
          <AppText style={{ flex: 1 }}>{shownValue || t(data.language, 'chooseWilaya')}</AppText>
          <Feather name="chevron-down" size={18} color={colors.mutedForeground} />
        </Pressable>
      </View>
      <Modal visible={visible} transparent animationType="slide" onRequestClose={() => setVisible(false)}>
        <View style={[styles.modalBackdrop, { backgroundColor: colors.overlay }]}>
          <View style={[styles.modalPanel, { backgroundColor: colors.background, borderColor: colors.border }]}>
            <View style={styles.rowBetween}>
              <AppText style={{ fontSize: 18, fontWeight: '700', color: colors.deepNavy }}>
                {t(data.language, 'chooseWilaya')}
              </AppText>
              <Pressable accessibilityRole="button" accessibilityLabel={t(data.language, 'cancel')} onPress={() => setVisible(false)}>
                <Feather name="x" size={21} color={colors.foreground} />
              </Pressable>
            </View>
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder={t(data.language, 'search')}
              placeholderTextColor={colors.mutedForeground}
              style={[styles.input, { backgroundColor: colors.card, borderColor: colors.border, color: colors.foreground }]}
            />
            <FlatList
              data={filtered}
              keyExtractor={(item) => item}
              keyboardShouldPersistTaps="handled"
              renderItem={({ item }) => (
                <Pressable
                  accessibilityRole="button"
                  onPress={() => {
                    const index = options.indexOf(item);
                    onSelect(wilayasFor('fr')[index] ?? item);
                    setVisible(false);
                  }}
                  style={[styles.wilayaRow, { borderBottomColor: colors.border }]}
                >
                  <AppText>{item}</AppText>
                  {item === shownValue ? <Feather name="check" size={17} color={colors.primary} /> : null}
                </Pressable>
              )}
              ListEmptyComponent={
                <View style={{ padding: 24, alignItems: 'center' }}>
                  <AppText style={{ color: colors.mutedForeground }}>Aucun résultat</AppText>
                </View>
              }
            />
          </View>
        </View>
      </Modal>
    </>
  );
}

export function LoadingScreen() {
  const colors = useColors();
  return (
    <View style={[styles.loading, { backgroundColor: colors.background }]}>
      <ActivityIndicator size="large" color={colors.primary} />
    </View>
  );
}

export function FormError({ children }: { children: React.ReactNode }) {
  const colors = useColors();
  return (
    <View style={[styles.formError, { backgroundColor: colors.dangerSurface }]}>
      <Feather name="alert-circle" size={16} color={colors.signal} />
      <AppText style={{ color: colors.signal, flex: 1, fontSize: 13 }}>{children}</AppText>
    </View>
  );
}

export function Divider() {
  const colors = useColors();
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: colors.border, width: '100%' }} />;
}

const styles = StyleSheet.create({
  pageContent: { paddingHorizontal: 20, gap: 20 },
  rowBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  card: { padding: 17, borderWidth: 1, gap: 14 },
  button: { minHeight: 48, paddingHorizontal: 16, borderRadius: 16, flexDirection: 'row', gap: 9, alignItems: 'center', justifyContent: 'center', borderWidth: 1 },
  buttonText: { fontWeight: '700', fontSize: 14 },
  input: { minHeight: 48, borderWidth: 1, borderRadius: 14, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15 },
  badge: { alignSelf: 'flex-start', borderRadius: 99, paddingHorizontal: 10, paddingVertical: 6 },
  demoBanner: { borderWidth: 1, borderRadius: 16, padding: 12, gap: 10, flexDirection: 'row', alignItems: 'flex-start' },
  modalBackdrop: { flex: 1, justifyContent: 'flex-end' },
  modalPanel: { maxHeight: '88%', borderTopLeftRadius: 24, borderTopRightRadius: 24, borderWidth: 1, padding: 20, paddingBottom: 30, gap: 16 },
  wilayaRow: { minHeight: 48, borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 4 },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  formError: { flexDirection: 'row', alignItems: 'center', gap: 9, borderRadius: 14, padding: 12 },
});

function makeStyles(colors: ReturnType<typeof useColors>) {
  return StyleSheet.create({
    page: { flex: 1, backgroundColor: colors.background },
    pageContent: { paddingHorizontal: 20, gap: 20 },
  });
}
