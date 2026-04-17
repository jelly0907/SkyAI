import SwiftUI
import Combine

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var navigationPath = NavigationPath()

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Search Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Where do you want to go?")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)

                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)

                                TextField("Search flights or cities", text: $viewModel.naturalQuery)
                                    .font(.system(size: 16))
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.none)

                                if viewModel.isParsingIntent {
                                    ProgressView()
                                        .scaleEffect(0.8, anchor: .center)
                                } else {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(20)

                        // Interpretation Text
                        if !viewModel.interpretation.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))

                                    Text(viewModel.interpretation)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Error Message
                        if let error = viewModel.intentError {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))

                                    Text(error)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                                .padding(12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                        }

                        // Structured Form Toggle
                        Button(action: {
                            withAnimation {
                                viewModel.showStructuredForm.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.showStructuredForm ? "chevron.up" : "chevron.down")
                                Text("Edit details")
                                Spacer()
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(primaryColor)
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Structured Form
                        if viewModel.showStructuredForm {
                            StructuredFormView(viewModel: viewModel)
                                .padding(20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer()
                    }
                }

                // Search Button
                Button(action: {
                    Task {
                        await viewModel.search()
                        if viewModel.shouldNavigateToResults {
                            navigationPath.append(viewModel.searchRequest)
                            viewModel.shouldNavigateToResults = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "airplane.departure")
                        Text("Search Flights")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(20)
                .disabled(viewModel.isParsingIntent)
                .opacity(viewModel.isParsingIntent ? 0.6 : 1.0)
            }
            .navigationDestination(for: SearchRequest.self) { request in
                ResultsView(searchRequest: request)
            }
        }
    }
}

struct StructuredFormView: View {
    @ObservedObject var viewModel: SearchViewModel

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)

    var body: some View {
        VStack(spacing: 16) {
            // Origin & Destination
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("From")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextField("SFO", text: $viewModel.searchRequest.originCode)
                        .font(.system(size: 16, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("To")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextField("NRT", text: $viewModel.searchRequest.destinationCode)
                        .font(.system(size: 16, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }

            // Trip Type
            Picker("Trip Type", selection: $viewModel.searchRequest.tripType) {
                ForEach(TripType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Dates
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Depart")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    DatePicker(
                        "Departure",
                        selection: $viewModel.searchRequest.departureDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                if viewModel.searchRequest.tripType != .oneWay {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Return")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        DatePicker(
                            "Return",
                            selection: Binding(
                                get: { viewModel.searchRequest.returnDate ?? Date() },
                                set: { viewModel.searchRequest.returnDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                }
            }

            // Passengers & Cabin
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adults")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Stepper(
                        value: $viewModel.searchRequest.adults,
                        in: 1...9
                    ) {
                        Text("\(viewModel.searchRequest.adults)")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cabin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("Cabin", selection: $viewModel.searchRequest.cabinClass) {
                        ForEach(CabinClass.allCases, id: \.self) { cabin in
                            Text(cabin.displayName).tag(cabin)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Direct Flights Toggle
            Toggle("Direct flights only", isOn: $viewModel.searchRequest.directFlightsOnly)
                .font(.system(size: 16))
                .tint(Color(red: 1.0, green: 0.42, blue: 0.21))
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onChange(of: viewModel.searchRequest.tripType) { _ in
            viewModel.setDefaultReturnDate()
        }
    }
}

#Preview {
    SearchView()
}
