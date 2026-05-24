package main

import (
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Define Prometheus counters for request metrics
var (
	requestMethodCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path"},
	)
	responseStatusCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_responses_total",
			Help: "Total number of HTTP responses",
		},
		[]string{"status_code", "method", "path"},
	)
)

var log *slog.Logger

func init() {
	log = slog.New(slog.NewTextHandler(os.Stdout, nil))
	// Register Prometheus metrics
	prometheus.MustRegister(requestMethodCounter)
	prometheus.MustRegister(responseStatusCounter)
}

func randomSleepDuration() time.Duration {
	// Generate a random sleep duration between 1 to 4 seconds
	rand.Seed(time.Now().UnixNano())
	sleepSeconds := rand.Intn(2)
	return time.Duration(sleepSeconds) * time.Second
}

func handler(w http.ResponseWriter, r *http.Request) {
	// Increment request method and path counter
	requestMethodCounter.WithLabelValues(r.Method, r.URL.Path).Inc()

	// Set the response header
	w.Header().Set("Content-Type", "text/plain")

	log.Info("request", "method", r.Method, "path", r.RequestURI)
	// Check the request method
	switch r.Method {
	case http.MethodGet, http.MethodPost:
		// Respond with "Hodor" for both GET and POST requests
		time.Sleep(randomSleepDuration())
		fmt.Fprint(w, "hodor... hodor... hodor")
	default:
		// Respond with a 405 Method Not Allowed for other request methods
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
	}
	responseStatusCounter.WithLabelValues(fmt.Sprint(http.StatusOK), r.Method, r.URL.Path).Inc()
}

func main() {
	// Register the handler function for all routes
	http.HandleFunc("/", handler)
	// Register Prometheus endpoint
	http.Handle("/metrics", promhttp.Handler())

	addr := os.Getenv("HOST_ADDR")
	if addr == "" {
		addr = "localhost:8080"
	}

	// Start the server on port 8080
	log.Info("Staring server", "addr", addr)
	err := http.ListenAndServe(addr, nil)
	if err != nil {
		log.Info("Failed to start", "err", err)
	}
}
