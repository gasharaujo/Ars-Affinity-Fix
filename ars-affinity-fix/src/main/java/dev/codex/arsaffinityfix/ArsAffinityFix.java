package dev.codex.arsaffinityfix;

import net.neoforged.fml.common.Mod;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Mod(ArsAffinityFix.MOD_ID)
public final class ArsAffinityFix {
    public static final String MOD_ID = "ars_affinity_fix";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    public ArsAffinityFix() {
        LOGGER.info("Ars Affinity Fix 1.0.0 loaded");
    }
}
