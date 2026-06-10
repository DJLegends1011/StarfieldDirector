namespace
{
    void MessageCallback(SFSE::MessagingInterface::Message* a_msg)
    {
        switch (a_msg->type) {
            case SFSE::MessagingInterface::kPostLoad:
                REX::INFO("Director: received kPostLoad");
                break;
            case SFSE::MessagingInterface::kPostPostLoad:
                REX::INFO("Director: received kPostPostLoad");
                break;
            case SFSE::MessagingInterface::kPostDataLoad:
                REX::INFO("Director: received kPostDataLoad");
                break;
            case SFSE::MessagingInterface::kPostPostDataLoad:
                REX::INFO("Director: received kPostPostDataLoad");
                break;
            default:
                REX::WARN("Director: received unknown message type");
                break;
        }
    }
}

SFSE_PLUGIN_PRELOAD(const SFSE::PreLoadInterface* a_sfse)
{
    // Not redundant with the Init in Load: different overload (PreLoadInterface),
    // runs in the preload phase before game data is available.
    SFSE::Init(a_sfse);

    return true;
}

SFSE_PLUGIN_LOAD(const SFSE::LoadInterface* a_sfse)
{
    // Load-phase overload (LoadInterface) — enables GetMessagingInterface() etc.
    SFSE::Init(a_sfse);

    REX::INFO("Director v0.0.1 loaded");  // TODO: derive version from plugin version data instead of literal

    const auto messaging = SFSE::GetMessagingInterface();
    if (!messaging || !messaging->RegisterListener(MessageCallback)) {
        // TODO: once this plugin owns real resources, release them on this failure path
        REX::ERROR("Director: failed to register SFSE message listener");
        return false;
    }
    REX::INFO("Director: message listener registered");

    return true;
}
