package dev.codex.arsaffinityfix.mixin;

import com.hollingsworth.arsnouveau.api.spell.Spell;
import com.hollingsworth.arsnouveau.api.spell.SpellResolver;
import com.hollingsworth.arsnouveau.api.spell.SpellStats;
import com.hollingsworth.arsnouveau.api.spell.wrapped_caster.PlayerCaster;
import dev.codex.arsaffinityfix.ArsAffinityFix;
import net.minecraft.world.level.Level;
import org.spongepowered.asm.mixin.Dynamic;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Makes Ars Affinity account a SpellResolver only once.
 *
 * <p>Ars Affinity 1.1.1 injects at the head of onResolveEffect and walks the
 * complete spell recipe on every resolution. Burst, chained and multi-target
 * spells therefore account the same recipe repeatedly. The method targeted
 * here is merged into SpellResolver by Ars Affinity's higher-priority mixin.
 * This fix intentionally runs later (priority 900 in the mixin config).</p>
 */
@Mixin(value = SpellResolver.class, priority = 900, remap = false)
public abstract class SpellTrackingDedupMixin {
    @Unique
    private boolean arsAffinityFix$affinityAccounted;

    @Unique
    private static boolean arsAffinityFix$deduplicationReported;

    @Dynamic("Method merged into SpellResolver by Ars Affinity's SpellTrackingMixin")
    @Inject(method = "trackSpellUsage", at = @At("HEAD"), cancellable = true, require = 1)
    private void arsAffinityFix$accountResolverOnce(
            PlayerCaster caster,
            Spell spell,
            SpellStats stats,
            Level level,
            CallbackInfo ci
    ) {
        if (arsAffinityFix$affinityAccounted) {
            if (!arsAffinityFix$deduplicationReported) {
                arsAffinityFix$deduplicationReported = true;
                ArsAffinityFix.LOGGER.info("Repeated Ars Affinity spell resolution successfully suppressed");
            }
            ci.cancel();
            return;
        }

        arsAffinityFix$affinityAccounted = true;
    }
}
