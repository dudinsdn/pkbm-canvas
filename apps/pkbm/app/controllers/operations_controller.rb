class OperationsController < ActionController::API
  before_action :authenticate!, except: [:login]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from OperationWriter::Forbidden do |error|
    render json: { error: error.message }, status: :forbidden
  end
  rescue_from OperationWriter::Invalid, ActiveRecord::RecordInvalid, ArgumentError do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end
  rescue_from ActiveRecord::StatementInvalid do
    render json: { error: "Data atau relasi tidak memenuhi batas database" }, status: :unprocessable_entity
  end

  def login
    # Local companion identities, independent of Canvas. Never accepts role/tenant headers.
    pkbm = ActiveRecord::Base.connection.select_one("SELECT id,name FROM pkbms WHERE local_code=#{ActiveRecord::Base.connection.quote(params[:pkbm_code].to_s)}")
    person = pkbm && OperationRecord.for("people").find_by(pkbm_id: pkbm["id"], email: params[:email].to_s.strip.downcase)
    member = person && OperationRecord.for("pkbm_memberships").find_by(pkbm_id: pkbm["id"], person_id: person.id, status: "active")
    digest = person&.password_digest || "pbkdf2_sha256$210000$00000000000000000000000000000000$#{'0' * 64}"
    valid = LocalCredentials.valid?(params[:password], digest)
    return render json: { error: "Identitas atau password tidak sesuai" }, status: :unauthorized unless valid && member
    token = verifier.generate({ "pkbm_id" => member.pkbm_id, "membership_id" => member.id }, expires_in: 8.hours, purpose: "pkbm_operations")
    response.headers["Cache-Control"] = "no-store"
    render json: { token: token, expires_in_seconds: 28_800 }
  end

  def me
    member = @scope.base("pkbm_memberships").find(@scope.membership_id)
    person = @scope.base("people").find(member.person_id)
    render json: { pkbm_id: @scope.pkbm_id, membership_id: member.id, name: person.name, roles: @scope.roles }
  end

  def index
    response.headers["Cache-Control"] = "no-store"
    render json: { records: @scope.records(table).order(:created_at, :id).limit(500).map { |record| serialize(record) }, limit: 500 }
  end

  def show
    render json: serialize(@scope.records(table).find(params[:id]))
  end

  def create
    record = OperationWriter.new(@scope).save(table, params.require(:record).permit!.to_h)
    render json: serialize(record), status: :created
  end

  def update
    record = OperationWriter.new(@scope).save(table, params.require(:record).permit!.to_h, id: params[:id])
    render json: serialize(record)
  end

  private

  def serialize(record)
    fields = record.attributes.except("password_digest")
    if record.class.table_name == "people" && !@scope.manager?
      own_person = @scope.base("pkbm_memberships").find(@scope.membership_id).person_id
      fields.delete("email") unless record.id == own_person
    end
    fields
  end
  def verifier = Rails.application.message_verifier("pkbm_operations")
  def table
    name = params[:collection].to_s
    raise ActiveRecord::RecordNotFound unless OperationRecord::TABLES.include?(name)
    name
  end

  def authenticate!
    response.headers["Cache-Control"] = "no-store"
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    identity = verifier.verified(token, purpose: "pkbm_operations")
    member = identity && OperationRecord.for("pkbm_memberships").find_by(id: identity["membership_id"], pkbm_id: identity["pkbm_id"], status: "active")
    return render json: { error: "Silakan masuk kembali" }, status: :unauthorized unless member
    @scope = OperationScope.new(member.pkbm_id, member.id)
  end

  def not_found
    render json: { error: "Data tidak tersedia pada lingkup akses ini" }, status: :not_found
  end
end
