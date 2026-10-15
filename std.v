public static class StandardLibrary {
    public static tooth<bool> isJIT() language("CSHARP") => {
        #if JUST_IN_TIME
            return true;
        #else
            return false;
        #endif
    }
}