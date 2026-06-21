package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

const defaultGeminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/openai"

type GeminiProvider struct {
	apiKey  string
	model   string
	baseURL string
	client  *http.Client
}

func newGeminiProvider(apiKey, model, baseURL string) *GeminiProvider {
	if model == "" {
		model = "gemini-2.0-flash"
	}
	if baseURL == "" {
		baseURL = defaultGeminiBaseURL
	}
	return &GeminiProvider{
		apiKey:  apiKey,
		model:   model,
		baseURL: strings.TrimRight(baseURL, "/"),
		client:  &http.Client{},
	}
}

func (p *GeminiProvider) Available() bool {
	return p.apiKey != ""
}

type openAIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIRequest struct {
	Model          string          `json:"model"`
	Messages       []openAIMessage `json:"messages"`
	MaxTokens      int             `json:"max_tokens,omitempty"`
	Temperature    float32         `json:"temperature,omitempty"`
	ResponseFormat *struct {
		Type string `json:"type"`
	} `json:"response_format,omitempty"`
}

type openAIResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Model string `json:"model"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
	} `json:"usage"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error"`
}

func (p *GeminiProvider) Complete(ctx context.Context, req CompletionRequest) (CompletionResponse, error) {
	maxTokens := req.MaxTokens
	if maxTokens <= 0 {
		maxTokens = 2048
	}

	messages := []openAIMessage{}
	if req.SystemPrompt != "" {
		messages = append(messages, openAIMessage{Role: "system", Content: req.SystemPrompt})
	}
	messages = append(messages, openAIMessage{Role: "user", Content: req.UserPrompt})

	body := openAIRequest{
		Model:       p.model,
		Messages:    messages,
		MaxTokens:   maxTokens,
		Temperature: req.Temperature,
	}
	if req.JSONMode {
		body.ResponseFormat = &struct {
			Type string `json:"type"`
		}{Type: "json_object"}
	}

	raw, err := json.Marshal(body)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: gemini marshal request: %w", err)
	}

	url := p.baseURL + "/chat/completions"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: gemini build request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	resp, err := p.client.Do(httpReq)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: gemini request: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: gemini read response: %w", err)
	}

	var or openAIResponse
	if err := json.Unmarshal(respBytes, &or); err != nil {
		return CompletionResponse{}, fmt.Errorf("ai: gemini parse response: %w", err)
	}

	if or.Error != nil {
		return CompletionResponse{}, fmt.Errorf("ai: gemini api error [%s]: %s", or.Error.Type, or.Error.Message)
	}

	if len(or.Choices) == 0 {
		return CompletionResponse{}, fmt.Errorf("ai: gemini empty response")
	}

	return CompletionResponse{
		Content: or.Choices[0].Message.Content,
		Model:   or.Model,
		Usage: UsageStats{
			InputTokens:  or.Usage.PromptTokens,
			OutputTokens: or.Usage.CompletionTokens,
		},
	}, nil
}
