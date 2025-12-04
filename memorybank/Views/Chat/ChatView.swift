import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var noteStore: NoteStore
    
    @FocusState private var isInputFocused: Bool
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 메시지 목록
                messageListView
                
                Divider()
                
                // 입력 영역
                inputView
            }
            .navigationTitle("AI 튜터")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert("대화 초기화", isPresented: $showingClearAlert) {
                Button("취소", role: .cancel) {}
                Button("초기화", role: .destructive) {
                    chatViewModel.clearChat()
                }
            } message: {
                Text("모든 대화 내용이 삭제됩니다.")
            }
        }
    }
    
    // MARK: - Message List
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatViewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            noteStore: noteStore
                        )
                        .id(message.id)
                    }
                    
                    // 로딩 표시
                    if chatViewModel.isLoading {
                        HStack {
                            TypingIndicatorView()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(chatViewModel.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: chatViewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input View
    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("메시지를 입력하세요...", text: $chatViewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .focused($isInputFocused)
                .lineLimit(1...5)
            
            Button {
                Task {
                    await chatViewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray
                        : Color.blue
                    )
            }
            .disabled(chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let noteStore: NoteStore
    
    @State private var showingNoteDetail: Note?
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // 메시지 내용
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .cornerRadius(20)
                
                // 참조 노트
                if !message.referencedNoteIds.isEmpty {
                    referencedNotesView
                }
                
                // 시간
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .sheet(item: $showingNoteDetail) { note in
            NoteDetailView(note: note)
                .environmentObject(noteStore)
        }
    }
    
    private var referencedNotesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("참조 노트")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(message.referencedNoteIds, id: \.self) { noteId in
                        if let note = noteStore.getNote(id: noteId) {
                            Button {
                                showingNoteDetail = note
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                    Text(note.title)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    @State private var animationOffset = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset == index ? -5 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever()) {
                animationOffset = (animationOffset + 1) % 3
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatViewModel())
        .environmentObject(NoteStore())
}
