import { Feather } from '@expo/vector-icons';
import { useAudioPlayer } from 'expo-audio';
import { router } from 'expo-router';
import * as Haptics from 'expo-haptics';
import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ActionButton, AppText } from '@/components/AppUI';
import { useColors } from '@/hooks/useColors';
import { useApp } from '@/lib/app-context';
import { t } from '@/lib/i18n';

export default function EmergencyScreen() {
  const { data, addTestAlert, captureLocation } = useApp();
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const player = useAudioPlayer(require('../assets/sounds/alert-tone.wav'));
  const [remaining, setRemaining] = useState(15);
  const [complete, setComplete] = useState(false);
  const [locating, setLocating] = useState(false);

  useEffect(() => {
    player.loop = true;
    player.play();
    return () => {
      player.pause();
    };
  }, [player]);

  useEffect(() => {
    let active = true;
    const timer = setInterval(() => {
      setRemaining((current) => {
        const next = current - 1;
        if (next <= 0 && active) {
          active = false;
          player.pause();
          addTestAlert();
          setComplete(true);
          void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning).catch(() => {});
          return 0;
        }
        if (next > 0 && next <= 5) {
          void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy).catch(() => {});
        }
        return Math.max(0, next);
      });
    }, 1000);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, [addTestAlert, player]);

  const cancel = () => {
    player.pause();
    router.back();
  };

  const copy = (key: string) => t(data.language, key);
  const diameter = 220;
  const progress = remaining / 15;

  return (
    <View style={[styles.screen, { backgroundColor: colors.deepNavy, paddingTop: insets.top + 22, paddingBottom: insets.bottom + 22 }]}>
      <View style={styles.topline}>
        <View style={styles.logoMark}>
          <Feather name="shield" size={17} color={colors.primaryForeground} />
        </View>
        <AppText style={{ color: colors.primaryForeground, opacity: 0.75, fontSize: 12, fontWeight: '700', letterSpacing: 1.3 }}>
          SOLVEX ALERT · TEST
        </AppText>
        <View style={{ flex: 1 }} />
        <View style={[styles.liveTag, { backgroundColor: colors.warning }]}>
          <AppText style={{ color: colors.deepNavy, fontSize: 10, fontWeight: '800' }}>DÉMO</AppText>
        </View>
      </View>

      <View style={styles.center}>
        <View style={[styles.pulseOuter, { width: diameter + 36, height: diameter + 36, borderColor: colors.signal }]}>
          <View style={[styles.pulseRing, { width: diameter, height: diameter, borderColor: colors.signal }]}>
            <View style={[styles.countCircle, { backgroundColor: colors.signal }]}>
              {!complete ? (
                <>
                  <AppText style={{ color: colors.primaryForeground, fontSize: 64, fontWeight: '800', letterSpacing: -2 }}>{remaining}</AppText>
                  <AppText style={{ color: colors.primaryForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.2 }}>SECONDES</AppText>
                </>
              ) : (
                <Feather name="check" size={58} color={colors.primaryForeground} />
              )}
            </View>
          </View>
        </View>
        <AppText style={{ color: colors.primaryForeground, fontSize: 22, fontWeight: '700', textAlign: 'center', marginTop: 30 }}>
          {complete ? copy('simulated') : copy('countdown')}
        </AppText>
        <AppText style={{ color: colors.primaryForeground, opacity: 0.72, fontSize: 14, lineHeight: 21, textAlign: 'center', maxWidth: 300, marginTop: 9 }}>
          {complete
            ? `${copy('noDispatch')} L’événement est conservé localement.`
            : `Véhicule : ${data.vehicleType === 'car' ? copy('car') : copy('motorcycle')} · Wilaya : ${data.wilaya}. Annulez si vous êtes en sécurité.`}
        </AppText>
      </View>

      {!complete ? (
        <View style={{ gap: 13 }}>
          <Pressable
            accessibilityRole="button"
            testID="cancel-test-alarm"
            onPress={cancel}
            style={({ pressed }) => [
              styles.cancelButton,
              {
                backgroundColor: colors.card,
                opacity: pressed ? 0.87 : 1,
                transform: [{ scale: pressed ? 0.985 : 1 }],
              },
            ]}
          >
            <Feather name="check-circle" size={22} color={colors.success} />
            <AppText style={{ color: colors.deepNavy, fontSize: 15, fontWeight: '800', textAlign: 'center' }}>
              {copy('cancelAlarm')}
            </AppText>
          </Pressable>
          <ActionButton
            label={locating ? 'Localisation…' : copy('getLocation')}
            icon="map-pin"
            variant="outline"
            disabled={locating}
            onPress={async () => {
              setLocating(true);
              await captureLocation();
              setLocating(false);
            }}
            style={{ borderColor: colors.primaryForeground, backgroundColor: 'transparent' }}
          />
          <AppText style={{ color: colors.primaryForeground, opacity: 0.62, fontSize: 11, textAlign: 'center', lineHeight: 16 }}>
            Aucun SMS, appel ou signalement aux secours ne sera envoyé.
          </AppText>
        </View>
      ) : (
        <ActionButton
          label="Voir l’historique"
          icon="clock"
          onPress={() => router.replace('/(tabs)/history')}
          style={{ backgroundColor: colors.card }}
        />
      )}
      <View style={[styles.progressTrack, { backgroundColor: colors.secondary }]}>
        <View style={[styles.progressFill, { width: `${progress * 100}%`, backgroundColor: colors.signal }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, paddingHorizontal: 22, justifyContent: 'space-between' },
  topline: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  logoMark: { width: 34, height: 34, borderRadius: 12, backgroundColor: 'rgba(255,255,255,0.12)', alignItems: 'center', justifyContent: 'center' },
  liveTag: { borderRadius: 99, paddingHorizontal: 10, paddingVertical: 7 },
  center: { alignItems: 'center', justifyContent: 'center', flex: 1 },
  pulseOuter: { borderWidth: 1, borderRadius: 999, alignItems: 'center', justifyContent: 'center', opacity: 0.3 },
  pulseRing: { borderWidth: 1, borderRadius: 999, alignItems: 'center', justifyContent: 'center', opacity: 1 },
  countCircle: { width: 174, height: 174, borderRadius: 87, alignItems: 'center', justifyContent: 'center', gap: 2 },
  cancelButton: { minHeight: 64, borderRadius: 20, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12, paddingHorizontal: 18 },
  progressTrack: { height: 4, borderRadius: 2, overflow: 'hidden', marginTop: 18 },
  progressFill: { height: '100%', borderRadius: 2 },
});
