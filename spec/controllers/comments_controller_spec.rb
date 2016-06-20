require 'spec_helper'
require 'policy_spec_helper'

describe CommentsController do
  render_views
  let(:institution)    { Institution.make }
  let(:user)           { institution.user }
  let(:patient)        { Patient.make institution: institution }
  let(:default_params) { { context: institution.uuid } }
  let(:valid_params)   { {
    description:  'New valid comment',
    comment:      'For whom the bell tolls'
  } }

  context 'user with edit patient permission' do
    before(:each) do
      sign_in user
    end

    describe 'index' do
      let!(:comment) { Comment.make patient: patient }

      it 'should return a json with comments' do
        get 'index', patient_id: patient.id

        expect(JSON.parse(response.body).size).to eq(1)
      end
    end

    describe 'new' do
      it 'should render the new template' do
        get 'new', patient_id: patient.id

        expect(response).to  render_template('new')
      end
    end

    describe 'create' do
      context 'with valid data' do
        before :each do
          post :create, patient_id: patient.id, comment: valid_params
        end

        it 'should save the comment' do
          comment = patient.comments.where(description: 'New valid comment').first

          expect(comment.user).to     eq(user)
          expect(comment.uuid).not_to be_empty
          expect(comment.comment).to  eq('For whom the bell tolls')
        end

        it 'should redirect to the patients page' do
          expect(response).to redirect_to patient_path(patient)
        end

        context 'audited data do' do
          before :each do
            @audit_log = AuditLog.where(patient: patient, title: 'New comment added').first
          end

          it 'should audit the comment' do
            expect(@audit_log.comment).to eq('For whom the bell tolls')
          end
        end


      end

      describe 'comment date' do
        context 'if no date is provided ' do
          it 'should add today as default date' do
            post :create, patient_id: patient.id, comment: valid_params
            comment = patient.comments.where(description: 'New valid comment').first

            expect(comment.commented_on).to eq(Date.today)
          end
        end

        context 'if a date is provided' do
          it 'should be saved' do
            post :create, patient_id: patient.id, comment: valid_params.merge!({ commented_on: '11/26/2016' })

            comment = patient.comments.where(description: 'New valid comment').first

            expect(comment.commented_on).to eq(Date.new(2016, 11, 26))
          end
        end
      end

      context 'with invalid data' do
        it 'should render the edit page' do
          post :create, patient_id: patient.id, comment: { comment: 'Invalid' }

          expect(response).to render_template('new')
        end
      end
    end
  end

  context 'user with no edit patient permission' do
    let(:invalid_user)           { Institution.make.user }

    before(:each) do
      grant user, invalid_user, institution, READ_INSTITUTION

      sign_in invalid_user
    end

    describe 'new' do
      it 'should deny access' do
        get 'new', patient_id: patient.id

        expect(response).to redirect_to(patient_path(patient))
      end
    end

    describe 'create' do
      it 'should deny access' do
        post :create, patient_id: patient.id, comment: valid_params

        expect(response).to redirect_to(patient_path(patient))
      end
    end
  end
end
