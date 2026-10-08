package dev.codex.arsaffinityfix.mixin;

import com.github.ars_affinity.capability.PlayerAffinityData;
import com.github.ars_affinity.capability.PlayerAffinityDataProvider;
import dev.codex.arsaffinityfix.ArsAffinityFix;
import net.minecraft.world.entity.player.Player;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Mutable;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.Redirect;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Prevents the integrated server and the Minecraft client from resolving the
 * same UUID to the same mutable PlayerAffinityData instance.
 *
 * <p>Ars Affinity stores its cache in a static HashMap keyed only by UUID. In
 * singleplayer both logical sides live in one JVM, so the client sync handler
 * clears maps that the server is simultaneously iterating. A deterministic,
 * private client-side cache key preserves the real player UUID everywhere
 * outside this cache while keeping the two mutable objects independent.</p>
 */
@Mixin(value = PlayerAffinityDataProvider.class, remap = false)
public abstract class PlayerAffinityDataProviderMixin {
    @Unique
    private static final long ARS_AFFINITY_FIX_CLIENT_MSB_MASK = 0x4152534146464958L;

    @Unique
    private static final long ARS_AFFINITY_FIX_CLIENT_LSB_MASK = 0x434C49454E545349L;

    @Shadow
    @Final
    @Mutable
    private static Map<UUID, PlayerAffinityData> playerDataCache;

    @Inject(method = "<clinit>", at = @At("TAIL"))
    private static void arsAffinityFix$makeCacheThreadSafe(CallbackInfo ci) {
        playerDataCache = new ConcurrentHashMap<>(playerDataCache);
        ArsAffinityFix.LOGGER.info("Separated Ars Affinity client/server cache enabled");
    }

    @Redirect(
            method = {
                    "getPlayerAffinityData",
                    "savePlayerData",
                    "removePlayerData(Lnet/minecraft/world/entity/player/Player;)V"
            },
            at = @At(
                    value = "INVOKE",
                    target = "Lnet/minecraft/world/entity/player/Player;getUUID()Ljava/util/UUID;"
            ),
            require = 3
    )
    private static UUID arsAffinityFix$sideAwareCacheKey(Player player) {
        UUID realId = player.getUUID();
        if (!player.level().isClientSide()) {
            return realId;
        }

        return new UUID(
                realId.getMostSignificantBits() ^ ARS_AFFINITY_FIX_CLIENT_MSB_MASK,
                realId.getLeastSignificantBits() ^ ARS_AFFINITY_FIX_CLIENT_LSB_MASK
        );
    }
}
