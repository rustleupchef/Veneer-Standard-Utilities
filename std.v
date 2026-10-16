public static class StandardLibrary {
    public static tooth<bool> isJIT() language("CSHARP") => {
        #if JUST_IN_TIME
            return true;
        #else
            return false;
        #endif
    }

    public static tooth<bool> hasConfig() language("CSHARP") => {
        #if CONFIG
            return true;
        #else
            return false;
        #endif
    }

    public static tooth<string> getConfigContent() language("CSHARP") => |
        #if CONFIG
            return new StreamReader(
                Assembly
                    .GetExecutingAssembly()
                    .GetManifestResourceStream("Config")
                ).ReadToEnd();
        #else
            return "{}";
        #endif
    |

    public static tooth<Delegate> load(
        string path,
        string name,
        Type returnType,
        Type[] parameterTypes) language("CSHARP") => delimeter
        #if JUST_IN_TIME
            Type GetFuncType(Type[] _parameterTypes, Type _returnType)
            {
                Type[] typeArgs = _parameterTypes.Append(_returnType).ToArray();

                int genericArity = typeArgs.Length;
                string funcTypeName = $"System.Func`{genericArity}";

                Type funcDefinition = Type.GetType(funcTypeName);
                return funcDefinition.MakeGenericType(typeArgs);
            }

            IntPtr libHandle = NativeLibrary.Load(path);
            IntPtr procAddress = NativeLibrary.GetExport(libHandle, name);

            // 1. Create a dynamic assembly and module to host the runtime delegate
            var assemblyBuilder = System.Reflection.Emit.AssemblyBuilder.DefineDynamicAssembly(
                new System.Reflection.AssemblyName("DynamicDelegates"), 
                System.Reflection.Emit.AssemblyBuilderAccess.Run);
            var moduleBuilder = assemblyBuilder.DefineDynamicModule("DynamicModule");

            // 2. Define a unique, non-generic delegate type name
            string delegateName = $"Delegate_{Guid.NewGuid():N}";
            var typeBuilder = moduleBuilder.DefineType(
                delegateName, 
                System.Reflection.TypeAttributes.Public | System.Reflection.TypeAttributes.Sealed | System.Reflection.TypeAttributes.AutoClass, 
                typeof(MulticastDelegate));

            // 3. Define the constructor required for all delegates
            var ctorBuilder = typeBuilder.DefineConstructor(
                System.Reflection.MethodAttributes.RTSpecialName | System.Reflection.MethodAttributes.HideBySig | System.Reflection.MethodAttributes.Public, 
                System.Reflection.CallingConventions.Standard, 
                new Type[] { typeof(object), typeof(IntPtr) });
            ctorBuilder.SetImplementationFlags(System.Reflection.MethodImplAttributes.Runtime | System.Reflection.MethodImplAttributes.Managed);

            // 4. Define the Invoke method matching your signatures
            var methodBuilder = typeBuilder.DefineMethod(
                "Invoke", 
                System.Reflection.MethodAttributes.Public | System.Reflection.MethodAttributes.HideBySig | System.Reflection.MethodAttributes.NewSlot | System.Reflection.MethodAttributes.Virtual, 
                returnType, 
                parameterTypes);
            methodBuilder.SetImplementationFlags(System.Reflection.MethodImplAttributes.Runtime | System.Reflection.MethodImplAttributes.Managed);

            // 5. Bake the type and generate the delegate
            Type dynamicDelegateType = typeBuilder.CreateType();
            Delegate rawDelegate = (Delegate)Marshal.GetDelegateForFunctionPointer(procAddress, dynamicDelegateType);
            return Delegate.CreateDelegate(GetFuncType(parameterTypes, returnType), rawDelegate, rawDelegate.GetType().GetMethod("Invoke")!);
        #else
            return null;
        #endif
    delimeter
}