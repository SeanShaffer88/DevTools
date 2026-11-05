#pragma once
#if defined(_WIN32)
# if defined(DEVTOOLS_DLL_BUILD)
#  define DEVTOOLS_API __declspec(dllexport)
# else
#  define DEVTOOLS_API __declspec(dllimport)
# endif
#else
# define DEVTOOLS_API
#endif
#ifdef __cplusplus
extern "C" {
#endif
DEVTOOLS_API int __NAME___Add(int left, int right);
#ifdef __cplusplus
}
#endif
