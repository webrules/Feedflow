package com.feedflow.ui.screens.post

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feedflow.data.repository.ForumRepository
import com.feedflow.domain.model.Thread
import com.feedflow.domain.model.Comment
import com.feedflow.data.remote.ai.AIService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ThreadDetailUiState(
    val thread: Thread? = null,
    val comments: List<Comment> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val isTranslated: Boolean = false,
    val originalContent: String? = null
)

@HiltViewModel
class ThreadDetailViewModel @Inject constructor(
    private val repository: ForumRepository,
    private val aiService: AIService,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    val serviceId: String = checkNotNull(savedStateHandle["serviceId"])
    val threadId: String = checkNotNull(savedStateHandle["threadId"])

    private val _uiState = MutableStateFlow(ThreadDetailUiState(isLoading = true))
    val uiState: StateFlow<ThreadDetailUiState> = _uiState

    init {
        fetchThreadDetail()
    }

    private fun fetchThreadDetail() {
        viewModelScope.launch {
            try {
                // Try to get thread from repository (Local DB -> Service fallback)
                val thread = repository.getThread(serviceId, threadId)

                if (thread != null) {
                    _uiState.value = ThreadDetailUiState(
                        thread = thread,
                        comments = emptyList(),
                        isLoading = false
                    )

                    // If it's not RSS, perform a fresh fetch to get comments/updates
                    if (serviceId != "rss") {
                         val service = repository.getService(serviceId)
                         if (service != null) {
                             try {
                                 val (freshThread, comments, _) = service.fetchThreadDetail(threadId, 1)
                                 _uiState.value = _uiState.value.copy(
                                     thread = freshThread,
                                     comments = comments
                                 )
                             } catch (e: Exception) {
                                 // Ignore refresh error if we have cached data
                             }
                         }
                    }
                } else {
                    _uiState.value = ThreadDetailUiState(error = "Thread not found", isLoading = false)
                }
            } catch (e: Exception) {
                _uiState.value = ThreadDetailUiState(error = e.message, isLoading = false)
            }
        }
    }

    fun translateThread() {
        val currentState = _uiState.value
        if (currentState.isTranslated || currentState.thread == null) return

        viewModelScope.launch {
            _uiState.value = currentState.copy(isLoading = true)
            val thread = currentState.thread!!
            try {
                val translated = aiService.translate(thread.content, "en")

                _uiState.value = currentState.copy(
                    isLoading = false,
                    isTranslated = true,
                    originalContent = thread.content,
                    thread = thread.copy(content = translated)
                )
            } catch (e: Exception) {
                _uiState.value = currentState.copy(isLoading = false, error = e.message)
            }
        }
    }

    fun getWebUrl(): String {
        val thread = _uiState.value.thread ?: return ""
        val service = repository.getService(serviceId)
        return service?.getWebURL(thread) ?: ""
    }
}
