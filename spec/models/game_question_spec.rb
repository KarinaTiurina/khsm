# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса, в идеале весь наш функционал
# (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do
  # Задаем локальную переменную game_question, доступную во всех тестах этого
  # сценария: она будет создана на фабрике заново для каждого блока it,
  # где она вызывается.
  let(:game_question) do
    FactoryGirl.create(:game_question, a: 2, b: 1, c: 4, d: 3)
  end

  # Группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # Тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq(
        'a' => game_question.question.answer2,
        'b' => game_question.question.answer1,
        'c' => game_question.question.answer4,
        'd' => game_question.question.answer3
      )
    end

    it 'correct .answer_correct?' do
      # Именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end
  end

  describe '#text & #level delegates' do
    it 'check text' do
      expect(game_question.text).to eq game_question.question.text
    end

    it 'check level' do
      expect(game_question.level).to eq game_question.question.level
    end
  end

  describe '#correct_answer_key' do
    it 'should be "a"' do
      game_question.a, game_question.b = game_question.b, game_question.a
      expect(game_question.correct_answer_key).to eq "a"
    end

    it 'should be "b"' do
      expect(game_question.correct_answer_key).to eq "b"
    end
  end

  context 'user helpers' do
    it 'correct audience_help' do
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help

      expect(game_question.help_hash).to include(:audience_help)

      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end

  describe '#help_hash' do 
    it 'should save correctly' do 
      expect(game_question.help_hash).to eq({})

      game_question.help_hash[:key1] = 'value1'
      game_question.help_hash['key2'] = 'value2'

      expect(game_question.save).to be_truthy

      game_q = GameQuestion.find(game_question.id)

      expect(game_q.help_hash).to eq({key1: 'value1', 'key2' => 'value2'})
    end
  end

  describe '#add_fifty_fifty' do 
    it 'should add correct keys' do 
      expect(game_question.help_hash).not_to include(:fifty_fifty)      

      expect(game_question.add_fifty_fifty).to be_truthy

      gq = GameQuestion.find(game_question.id)

      expect(gq.help_hash).to include(:fifty_fifty)

      ff = gq.help_hash[:fifty_fifty]
      
      expect(ff).to include 'b'
      expect(ff.size).to eq 2
    end
  end
end
