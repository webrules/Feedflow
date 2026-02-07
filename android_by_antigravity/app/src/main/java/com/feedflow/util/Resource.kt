package com.feedflow.util

sealed class Resource<T>(val data: T? = null, val message: String? = null) {
    class Success<T>(data: T, val source: DataSource) : Resource<T>(data)
    class Loading<T>(data: T? = null) : Resource<T>(data)
    class Error<T>(message: String, data: T? = null) : Resource<T>(data, message)
}

enum class DataSource {
    LOCAL,
    CLOUD
}
